from django.urls import path
from .views import (
    SignUpView, 
    SignInView, 
    UserProfileView, 
    UpdatePointsView, 
    GetCompletedFormsView, 
    MarkFormCompletedView,
    CountFormsSubmittedView,
    AchievementImageUploadView,  # Endpoint for uploading achievement images
    # New endpoints for reward redemption workflow
    RedeemRewardView,
    ApproveRewardView,
    RedemptionRequestsView,
    SignOutView,
)

urlpatterns = [
    path('api/signup/', SignUpView.as_view(), name='signup'),
    path('api/signin/', SignInView.as_view(), name='signin'),
    path('api/user-profile/', UserProfileView.as_view(), name='user-profile'),
    path('api/update-points/', UpdatePointsView.as_view(), name='update-points'),
    path('api/get_completed_forms/', GetCompletedFormsView.as_view(), name='get-completed-forms'),
    path('api/mark_form_completed/', MarkFormCompletedView.as_view(), name='mark-form-completed'),
    path('api/count_forms_submitted/', CountFormsSubmittedView.as_view(), name='count-forms-submitted'),
    path('api/upload_achievement_image/', AchievementImageUploadView.as_view(), name='upload-achievement-image'),
    # Reward redemption endpoints
    path('api/redeem_reward/', RedeemRewardView.as_view(), name='redeem-reward'),
    path('api/approve_reward/', ApproveRewardView.as_view(), name='approve-reward'),
    path('api/redemption_requests/', RedemptionRequestsView.as_view(), name='redemption-requests'),
    path('api/signout/', SignOutView.as_view(), name='signout'),
]
