from django.urls import path
from .views import ProcessView, StatusView

urlpatterns = [
    path('process/', ProcessView.as_view()),
    path('status/<str:task_id>/', StatusView.as_view()),
    path('api/', include('api.urls')),
]