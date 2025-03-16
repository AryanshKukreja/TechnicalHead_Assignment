from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from django.contrib.auth import authenticate
from django.db import transaction, IntegrityError
from django.core.exceptions import ValidationError
from django.core.files.storage import default_storage
from django.utils import timezone
from django.db.models import F
import logging
import uuid

# Import RewardRedemption along with your existing models.
from .models import CustomUser, FormSubmission, AchievementImage, RewardRedemption
from .serializers import UserSerializer

logger = logging.getLogger(__name__)


class SignUpView(APIView):
    def post(self, request):
        data = request.data
        serializer = UserSerializer(data=data)
        
        # Prevent duplicate registrations with the same email.
        if CustomUser.objects.filter(email=data.get('email', '')).exists():
            logger.warning(f"Sign-up attempt with existing email: {data.get('email')}")
            return Response({'error': 'Email already exists'}, status=status.HTTP_400_BAD_REQUEST)
        
        if serializer.is_valid():
            try:
                with transaction.atomic():
                    user = serializer.save()
                    token = Token.objects.create(user=user)
                logger.info(f"User {user.email} successfully registered.")
                return Response({
                    'token': token.key,
                    'email': user.email,
                    'points': user.points
                }, status=status.HTTP_201_CREATED)
            except IntegrityError as e:
                logger.error(f"Database integrity error during signup: {str(e)}")
                return Response({'error': 'Could not create user account due to database constraint'}, 
                                status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            except ValidationError as e:
                logger.error(f"Validation error during signup for {data.get('email')}: {str(e)}")
                return Response({'error': 'Validation error while creating user'}, 
                                status=status.HTTP_400_BAD_REQUEST)
            except Exception as e:
                logger.error(f"Unexpected error during signup: {str(e)}")
                return Response({'error': 'An unexpected error occurred'}, 
                                status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        else:
            logger.error(f"Sign-up validation failed: {serializer.errors}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class SignInView(APIView):
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        
        try:
            user = CustomUser.objects.get(email=email)
        except CustomUser.DoesNotExist:
            logger.warning(f"Sign-in attempt with invalid email: {email}")
            return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)
        
        if user.check_password(password):
            token, created = Token.objects.get_or_create(user=user)
            logger.info(f"User {user.email} authenticated successfully.")
            return Response({
                'token': token.key,
                'email': user.email,
                'points': user.points
            }, status=status.HTTP_200_OK)
        
        logger.warning(f"Invalid password attempt for user: {email}")
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)


class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        logger.info(f"Profile data retrieved for user: {user.email}")
        return Response({
            'email': user.email,
            'points': user.points,
            'date_joined': user.date_joined
        }, status=status.HTTP_200_OK)


class UpdatePointsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        points = request.data.get('points')
        
        if points is None:
            logger.error("Points update failed: Points field is required")
            return Response({'error': 'Points field is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            points = int(points)
            if points < 0:
                logger.error(f"Points update failed: Negative value provided by {user.email}")
                return Response({'error': 'Points cannot be negative'}, status=status.HTTP_400_BAD_REQUEST)
            user.points = points
            user.save()
            logger.info(f"User {user.email} points updated to {user.points}")
            return Response({'points': user.points}, status=status.HTTP_200_OK)
        except ValueError:
            logger.error(f"Points update failed: Non-integer value provided by {user.email}")
            return Response({'error': 'Points must be an integer'}, status=status.HTTP_400_BAD_REQUEST)


class GetCompletedFormsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        completed_forms = FormSubmission.objects.filter(user=user, submitted=True).values_list('form_title', flat=True)
        logger.info(f"Completed forms retrieved for user: {user.email}")
        return Response({'completed_forms': list(completed_forms)}, status=status.HTTP_200_OK)


class MarkFormCompletedView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        form_title = request.data.get('form_title')
        if not form_title:
            logger.error("Form submission failed: Form title is missing")
            return Response({'error': 'Form title is required'}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user

        form_submission, created = FormSubmission.objects.get_or_create(user=user, form_title=form_title)
        if form_submission.submitted:
            logger.info(f"Form '{form_title}' already submitted by user: {user.email}")
            return Response({'message': 'This form has already been submitted.'}, status=status.HTTP_400_BAD_REQUEST)

        form_submission.submitted = True
        points_earned = 20  # default points for form completion
        form_submission.points_earned = points_earned

        try:
            with transaction.atomic():
                form_submission.save()
                logger.info(f"Form '{form_title}' submitted by user: {user.email}, earned {points_earned} points.")
                return Response({
                    'message': 'Form submitted successfully!',
                    'points': user.points
                }, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Error processing form submission for {user.email}: {str(e)}")
            return Response({'error': 'An error occurred while processing the form submission.'}, 
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CountFormsSubmittedView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        forms_count = request.user.forms_submitted_count()
        logger.info(f"User {request.user.email} has submitted {forms_count} forms.")
        return Response({'forms_submitted': forms_count}, status=status.HTTP_200_OK)


class AchievementImageUploadView(APIView):
    """
    Endpoint for uploading achievement images.
    Users can upload images via the Flutter app which are then stored in AWS S3.
    The S3 URL is saved in the AchievementImage model, allowing multiple images per user.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        user = request.user
        if 'image' not in request.FILES:
            logger.error(f"Achievement image upload failed: 'image' not found in request by user {user.email}")
            return Response({'error': 'Image file is required.'}, status=status.HTTP_400_BAD_REQUEST)
        
        image = request.FILES['image']
        unique_filename = f"user_{user.id}/{uuid.uuid4().hex}_{image.name}"
        
        try:
            s3_path = default_storage.save(unique_filename, image)
            s3_url = default_storage.url(s3_path)
            achievement_image = AchievementImage.objects.create(user=user, image_url=s3_url)
            logger.info(f"Achievement image uploaded for user {user.email}: {s3_url}")
            return Response({'url': s3_url}, status=status.HTTP_201_CREATED)
        except Exception as e:
            logger.error(f"Error uploading achievement image for user {user.email}: {str(e)}")
            return Response({'error': 'An error occurred while uploading the image.'},
                            status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --------------------- Reward Redemption Endpoints ---------------------

class RedeemRewardView(APIView):
    """
    Endpoint for users to request a reward redemption.
    Points are not deducted immediately; the request awaits admin approval.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        reward_name = request.data.get('reward_name')
        reward_points = request.data.get('reward_points')

        if not reward_name or reward_points is None:
            logger.error("Reward redemption request failed: reward_name or reward_points missing.")
            return Response({'error': 'Reward name and reward points are required.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            reward_points = int(reward_points)
        except ValueError:
            logger.error("Reward redemption request failed: reward_points is not an integer.")
            return Response({'error': 'Reward points must be an integer.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            redemption = RewardRedemption.objects.create(
                user=user,
                reward_name=reward_name,
                reward_points=reward_points,
                approved=False
            )
        except Exception as e:
            logger.error(f"Error creating reward redemption request for user {user.email}: {str(e)}")
            return Response({'error': 'An error occurred while creating the redemption request.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        logger.info(f"User {user.email} requested redemption for {reward_name} costing {reward_points} points.")
        return Response({
            'message': 'Reward redemption request submitted successfully. Await admin approval.',
            'redemption_request_id': redemption.id,
        }, status=status.HTTP_201_CREATED)


class ApproveRewardView(APIView):
    permission_classes = [IsAuthenticated, IsAdminUser]

    def post(self, request):
        redemption_request_id = request.data.get('redemption_request_id')
        if not redemption_request_id:
            logger.error("Reward approval failed: redemption_request_id is missing.")
            return Response({'error': 'Redemption request ID is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                # Retrieve the redemption request and lock it
                redemption = RewardRedemption.objects.select_for_update().get(id=redemption_request_id, approved=False)

                # Log the redemption details
                logger.info(f"Processing redemption request {redemption_request_id} for {redemption.reward_name}, {redemption.reward_points} points")

                # Approve the redemption and deduct points if applicable
                redemption.approved = True
                redemption.save()  # This triggers the save() method in the model, which handles points deduction

                return Response({
                    'message': 'Reward redemption approved and points deducted successfully.',
                    'user_points': redemption.user.points,
                    'redemption_id': redemption.id
                }, status=status.HTTP_200_OK)

        except RewardRedemption.DoesNotExist:
            logger.error(f"Reward approval failed: No pending redemption request with ID {redemption_request_id}.")
            return Response(
                {'error': 'No pending redemption request found with the given ID.'},
                status=status.HTTP_404_NOT_FOUND
            )
        except ValidationError as e:
            logger.error(f"Validation error when approving redemption: {str(e)}")
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error approving reward redemption: {str(e)}")
            return Response(
                {'error': f'An error occurred while approving the redemption request: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class RedemptionRequestsView(APIView):
    """
    Endpoint to fetch reward redemption requests.
    If the user is an admin, return all redemption requests.
    Otherwise, return only the requests for the authenticated user.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.is_staff or user.is_superuser:
            redemptions = RewardRedemption.objects.all()
        else:
            redemptions = RewardRedemption.objects.filter(user=user)

        data = []
        for redemption in redemptions:
            data.append({
                'id': redemption.id,
                'user_email': redemption.user.email,
                'reward_name': redemption.reward_name,
                'reward_points': redemption.reward_points,
                'approved': redemption.approved,
                'points_deducted': redemption.points_deducted,
                'request_date': redemption.requested_at.isoformat() if hasattr(redemption, 'requested_at') else '',
                'approval_date': redemption.approved_at.isoformat() if redemption.approved_at else None,
                'status': 'approved' if redemption.approved else 'pending'
            })

        logger.info(f"Redemption requests fetched for user {user.email}")
        return Response({'requests': data}, status=status.HTTP_200_OK)

# ------------------- Local Storage and Auth Helper Endpoints -------------------

class SignOutView(APIView):
    def post(self, request):
        # Invalidate token or perform any cleanup if necessary.
        # For token-based auth, sign out is handled on the client side by deleting the token.
        logger.info(f"User {request.user.email} signed out.")
        return Response({'message': 'Signed out successfully.'}, status=status.HTTP_200_OK)