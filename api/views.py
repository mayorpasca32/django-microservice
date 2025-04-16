from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .tasks import process_data

class ProcessView(APIView):
    def post(self, request):
        email = request.data.get('email')
        message = request.data.get('message')
        if not email or not message:
            return Response({'error': 'Invalid data'}, status=400)
        task = process_data.delay(email, message)
        return Response({'task_id': task.id}, status=202)

class StatusView(APIView):
    def get(self, request, task_id):
        from celery.result import AsyncResult
        result = AsyncResult(task_id)
        return Response({"status": result.status, "result": result.result})