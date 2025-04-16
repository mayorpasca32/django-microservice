from celery import shared_task
import time

@shared_task
def process_data(email, message):
    time.sleep(10)
    return f"Processed message from {email}: {message}"