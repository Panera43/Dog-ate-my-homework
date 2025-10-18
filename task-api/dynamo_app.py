from flask import Flask, request, jsonify
from flask_cors import CORS
import boto3
from boto3.dynamodb.conditions import Key
import uuid
from datetime import datetime
from decimal import Decimal

app = Flask(__name__)
CORS(app)

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')  # Change region if needed
table = dynamodb.Table('Tasks')  # Your DynamoDB table name

# Helper function to convert DynamoDB Decimal to regular numbers
def decimal_to_number(obj):
    if isinstance(obj, list):
        return [decimal_to_number(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: decimal_to_number(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    else:
        return obj

@app.route('/')
def home():
    return jsonify({
        "message": "Task API with DynamoDB is running!",
        "endpoints": {
            "GET /tasks": "Get all tasks",
            "POST /tasks": "Create a new task",
            "POST /tasks/<id>/complete": "Mark task complete and upload photo",
            "GET /tasks/<id>": "Get a specific task",
            "DELETE /tasks/<id>": "Delete a task"
        }
    })

@app.route('/tasks', methods=['GET'])
def get_tasks():
    """Get all tasks from DynamoDB"""
    try:
        response = table.scan()  # Gets all items (for small datasets)
        tasks = decimal_to_number(response.get('Items', []))
        
        # Sort by created_at (newest first)
        tasks.sort(key=lambda x: x.get('created_at', ''), reverse=True)
        
        return jsonify({"tasks": tasks, "count": len(tasks)}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/tasks/<task_id>', methods=['GET'])
def get_task(task_id):
    """Get a specific task from DynamoDB"""
    try:
        response = table.get_item(Key={'id': task_id})
        task = response.get('Item')
        
        if task:
            return jsonify(decimal_to_number(task)), 200
        return jsonify({"error": "Task not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/tasks', methods=['POST'])
def create_task():
    """Create a new task in DynamoDB"""
    try:
        data = request.json
        
        if not data or 'title' not in data:
            return jsonify({"error": "Title is required"}), 400
        
        new_task = {
            "id": str(uuid.uuid4()),
            "title": data['title'],
            "completed": False,
            "photo_url": None,
            "created_at": datetime.now().isoformat()
        }
        
        # Save to DynamoDB
        table.put_item(Item=new_task)
        
        return jsonify(new_task), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/tasks/<task_id>/complete', methods=['POST'])
def complete_task(task_id):
    """Mark task as complete and save photo in DynamoDB"""
    try:
        # First check if task exists
        response = table.get_item(Key={'id': task_id})
        task = response.get('Item')
        
        if not task:
            return jsonify({"error": "Task not found"}), 404
        
        # Get photo URL from request
        data = request.json or {}
        photo_url = data.get('photo_url', 'photo_uploaded.jpg')
        
        # Update the task in DynamoDB
        table.update_item(
            Key={'id': task_id},
            UpdateExpression='SET completed = :completed, photo_url = :photo, completed_at = :completed_at',
            ExpressionAttributeValues={
                ':completed': True,
                ':photo': photo_url,
                ':completed_at': datetime.now().isoformat()
            }
        )
        
        # Get the updated task
        response = table.get_item(Key={'id': task_id})
        updated_task = decimal_to_number(response.get('Item'))
        
        return jsonify({
            "message": "Task completed! 🐕",
            "task": updated_task
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/tasks/<task_id>', methods=['DELETE'])
def delete_task(task_id):
    """Delete a task from DynamoDB"""
    try:
        # Check if task exists first
        response = table.get_item(Key={'id': task_id})
        if 'Item' not in response:
            return jsonify({"error": "Task not found"}), 404
        
        # Delete from DynamoDB
        table.delete_item(Key={'id': task_id})
        
        return jsonify({"message": "Task deleted successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/seed-data', methods=['POST'])
def seed_data():
    """Add some initial tasks to DynamoDB (for testing)"""
    try:
        sample_tasks = [
            {"id": str(uuid.uuid4()), "title": "Feed Rex", "completed": False, "photo_url": None, "created_at": datetime.now().isoformat()},
            {"id": str(uuid.uuid4()), "title": "Walk Buddy", "completed": False, "photo_url": None, "created_at": datetime.now().isoformat()},
            {"id": str(uuid.uuid4()), "title": "Give treats", "completed": False, "photo_url": None, "created_at": datetime.now().isoformat()}
        ]
        
        for task in sample_tasks:
            table.put_item(Item=task)
        
        return jsonify({"message": "Sample data added!", "tasks": sample_tasks}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("\n🚀 Task API Server with DynamoDB Starting...")
    print("📍 Server will run at: http://localhost:5000")
    print("📱 Flutter should connect to: http://YOUR_COMPUTER_IP:5000")
    print("\n🗄️  Using DynamoDB table: 'Tasks'")
    print("⚠️  Make sure:")
    print("   1. DynamoDB table 'Tasks' exists with 'id' as partition key")
    print("   2. AWS credentials are configured (aws configure)")
    print("   3. You have permissions to access DynamoDB")
    print("\nEndpoints:")
    print("  GET    /tasks              - Get all tasks")
    print("  POST   /tasks              - Create task")
    print("  POST   /tasks/<id>/complete - Complete task")
    print("  DELETE /tasks/<id>         - Delete task")
    print("  POST   /seed-data          - Add sample tasks")
    print("\n")
    app.run(debug=True, host='0.0.0.0', port=5000)