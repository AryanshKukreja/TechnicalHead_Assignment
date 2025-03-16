from django.contrib import admin
from django.db import transaction
from django.utils import timezone
from .models import (
    CustomUser,
    CustomToken,
    FormSubmission,
    AchievementImage,
    RewardRedemption,
)
import logging

logger = logging.getLogger(__name__)

# CustomUser admin registration with key details visible.
class CustomUserAdmin(admin.ModelAdmin):
    list_display = ('email', 'is_staff', 'is_active', 'points', 'date_joined')
    search_fields = ('email',)
    ordering = ('email',)
    list_filter = ('is_staff', 'is_active')

# CustomToken admin registration to monitor token lifecycle.
class CustomTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'token', 'created_at', 'expires_at', 'is_expired')
    search_fields = ('user__email', 'token')
    ordering = ('-created_at',)

# FormSubmission admin to track submission statuses and points.
class FormSubmissionAdmin(admin.ModelAdmin):
    list_display = ('user', 'form_title', 'submitted', 'points_earned')
    search_fields = ('user__email', 'form_title')
    list_filter = ('submitted',)

# AchievementImage admin for monitoring uploaded achievement images.
class AchievementImageAdmin(admin.ModelAdmin):
    list_display = ('user', 'image_url', 'uploaded_at')
    search_fields = ('user__email',)
    ordering = ('-uploaded_at',)

# Custom admin action for approving reward redemptions.
def approve_reward_redemptions(modeladmin, request, queryset):
    for redemption in queryset:
        if not redemption.approved:
            # Mark as approved; the model's save() will process point deductions.
            redemption.approved = True
            try:
                with transaction.atomic():
                    redemption.save()
                    logger.info(
                        f"Admin approved reward redemption for {redemption.user.email} - Reward: {redemption.reward_name}"
                    )
            except Exception as e:
                logger.error(
                    f"Error approving reward redemption for {redemption.user.email}: {str(e)}"
                )
approve_reward_redemptions.short_description = "Approve selected reward redemptions"

# RewardRedemption admin with all details and the custom action.
class RewardRedemptionAdmin(admin.ModelAdmin):
    list_display = (
        'user', 
        'reward_name', 
        'reward_points', 
        'approved', 
        'requested_at', 
        'approved_at', 
        'points_deducted'
    )
    search_fields = ('user__email', 'reward_name')
    list_filter = ('approved', 'points_deducted', 'requested_at')
    ordering = ('-requested_at',)
    actions = [approve_reward_redemptions]

# Register all models with their respective ModelAdmin classes.
admin.site.register(CustomUser, CustomUserAdmin)
admin.site.register(CustomToken, CustomTokenAdmin)
admin.site.register(FormSubmission, FormSubmissionAdmin)
admin.site.register(AchievementImage, AchievementImageAdmin)
admin.site.register(RewardRedemption, RewardRedemptionAdmin)
