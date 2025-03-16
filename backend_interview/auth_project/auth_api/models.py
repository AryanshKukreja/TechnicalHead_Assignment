from django.db import models, transaction
from django.conf import settings
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.utils import timezone
from datetime import timedelta
from django.core.exceptions import ValidationError
import logging

logger = logging.getLogger(__name__)

class CustomUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(email, password, **extra_fields)

class CustomUser(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    points = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)
    
    objects = CustomUserManager()
    
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    def __str__(self):
        return self.email

    def forms_submitted_count(self):
        return self.formsubmission_set.filter(submitted=True).count()

class CustomToken(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def is_expired(self):
        return timezone.now() > self.expires_at

    def __str__(self):
        return f"Token for {self.user.email} - Expires at {self.expires_at}"

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + timedelta(days=1)
        super().save(*args, **kwargs)

class FormSubmission(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    form_title = models.CharField(max_length=255)
    points_earned = models.IntegerField(default=20)
    submitted = models.BooleanField(default=False)

    def __str__(self):
        status = 'Submitted' if self.submitted else 'Not Submitted'
        return f"{self.user.email} - {self.form_title} - {status}"

    def save(self, *args, **kwargs):
        update_points = False
        if self.pk:
            orig = FormSubmission.objects.get(pk=self.pk)
            if not orig.submitted and self.submitted:
                update_points = True
        else:
            if self.submitted:
                update_points = True

        if update_points:
            try:
                with transaction.atomic():
                    self.user.points += self.points_earned
                    self.user.save()
                    logger.info(
                        f"User {self.user.email} earned {self.points_earned} points for form '{self.form_title}'. Total points: {self.user.points}"
                    )
            except Exception as e:
                logger.error(
                    f"Error while updating points for {self.user.email} on form '{self.form_title}': {str(e)}"
                )
                raise

        super().save(*args, **kwargs)

class AchievementImage(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='achievement_images')
    image_url = models.URLField(max_length=1024)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"AchievementImage for {self.user.email} uploaded at {self.uploaded_at}"

class RewardRedemption(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='reward_redemptions')
    reward_name = models.CharField(max_length=255)
    reward_points = models.IntegerField()
    approved = models.BooleanField(default=False)
    requested_at = models.DateTimeField(auto_now_add=True)
    approved_at = models.DateTimeField(null=True, blank=True)
    points_deducted = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.user.email} - {self.reward_name} - {self.status}"

    @property
    def status(self):
        return "Approved" if self.approved else "Pending"

    def save(self, *args, **kwargs):
        """
        When a new approval is registered, ensure the user has sufficient points.
        If not, raise a ValidationError so that the transaction is aborted.
        """
        with transaction.atomic():
            # Ensure the reward points are positive
            if self.reward_points <= 0:
                logger.error(f"Invalid reward points ({self.reward_points}) for {self.reward_name}. Must be positive.")
                raise ValidationError("Reward points must be greater than zero.")

            # If the reward is being approved and points are not deducted yet
            if self.approved and not self.points_deducted:
                user = CustomUser.objects.select_for_update().get(pk=self.user.pk)

                # Check if the user has sufficient points
                if user.points < self.reward_points:
                    logger.error(
                        f"User {user.email} doesn't have enough points for reward '{self.reward_name}'. "
                        f"Required: {self.reward_points}, Available: {user.points}"
                    )
                    raise ValidationError("Insufficient points for redemption.")
                
                # Deduct points from the user
                user.points -= self.reward_points
                user.save()

                # Log the points deduction
                logger.info(f"User {user.email}'s points updated after reward redemption: {user.points}")

                # Update points_deducted and approval timestamp
                self.points_deducted = True
                self.approved_at = timezone.now()

            # Save the redemption record with the updated fields
            super().save(*args, **kwargs)
            logger.info(f"Reward redemption for {self.user.email} ({self.reward_name}) has been successfully processed.")

