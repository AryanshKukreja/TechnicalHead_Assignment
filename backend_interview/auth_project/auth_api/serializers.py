from rest_framework import serializers
from .models import CustomUser

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = ['email', 'password', 'points']
        extra_kwargs = {
            'password': {'write_only': True},
            'points': {'required': False}  # Mark points as not required
        }

    def create(self, validated_data):
        user = CustomUser.objects.create_user(**validated_data)
        return user
