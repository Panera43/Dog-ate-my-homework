from flask import Flask, request, jsonify
from flask_cors import CORS
import uuid
from datetime import datetime

app = Flask(__name__)
CORS(app)  # Allow Flutter to connect

# In-memory storage (resets when server restarts)
tasks = [
    {"id": "1", "title": "Feed Rex", "completed": False, "photo_url": None, "created_at": "2025-10-18T10:00:00"},
    {"id": "2", "title": "Walk Buddy", "completed": False, "photo_url": None, "created_at": "2025-10-18T10:00:00"},
    {"id": "3", "title": "Give treats", "completed": False, "photo_url": None, "created_at": "2025-10-18T10:00:00"}
]

photos = {}  # Store photos temporarily

@app.route('/')
def home():
    return jsonify({
        "message": "Task API is running!",
        "endpoints": {
            "GET /tasks": "Get all tasks",
            "POST /tasks": "Create a new task",
            "POST /tasks/<id>/complete": "Mark task complete and upload photo",
            "GET /tasks/<id>": "Get a specific task"
        }
    })

@app.route('/tasks', methods=['GET'])
def get_tasks():
    """Get all tasks"""
    return jsonify({"tasks": tasks, "count": len(tasks)}), 200

@app.route('/tasks/<task_id>', methods=['GET'])
def get_task(task_id):
    """Get a specific task"""
    task = next((t for t in tasks if t["id"] == task_id), None)
    if task:
        return jsonify(task), 200
    return jsonify({"error": "Task not found"}), 404

@app.route('/tasks', methods=['POST'])
def create_task():
    """Create a new task"""
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
    
    tasks.append(new_task)
    return jsonify(new_task), 201

@app.route('/tasks/<task_id>/complete', methods=['POST'])
def complete_task(task_id):
    """Mark task as complete and save photo"""
    task = next((t for t in tasks if t["id"] == task_id), None)
    
    if not task:
        return jsonify({"error": "Task not found"}), 404
    
    # Get photo from request (base64 or URL)
    data = request.json or {}
    photo_url = data.get('photo_url', 'photo_uploaded.jpg')
    
    # Mark as complete
    task['completed'] = True
    task['photo_url'] = photo_url
    task['completed_at'] = datetime.now().isoformat()
    
    return jsonify({
        "message": "Task completed! 🐕",
        "task": task
    }), 200

@app.route('/tasks/<task_id>', methods=['DELETE'])
def delete_task(task_id):
    """Delete a task"""
    global tasks
    task = next((t for t in tasks if t["id"] == task_id), None)
    
    if not task:
        return jsonify({"error": "Task not found"}), 404
    
    tasks = [t for t in tasks if t["id"] != task_id]
    return jsonify({"message": "Task deleted"}), 200

@app.route('/upload-photo', methods=['POST'])
def upload_photo():
    """Upload a photo (accepts base64 or file)"""
    if 'photo' in request.files:
        photo = request.files['photo']
        photo_id = str(uuid.uuid4())
        # In a real app, save to S3. For hackathon, just store ID
        photos[photo_id] = photo.filename
        return jsonify({"photo_url": f"/photos/{photo_id}"}), 201
    
    if 'photo_base64' in request.json:
        photo_id = str(uuid.uuid4())
        photos[photo_id] = request.json['photo_base64']
        return jsonify({"photo_url": f"/photos/{photo_id}"}), 201
    
    return jsonify({"error": "No photo provided"}), 400

if __name__ == '__main__':
    print("\n🚀 Task API Server Starting...")
    print("📍 Server will run at: http://localhost:5000")
    print("📱 Flutter should connect to: http://YOUR_COMPUTER_IP:5000")
    print("\nEndpoints:")
    print("  GET    /tasks              - Get all tasks")
    print("  POST   /tasks              - Create task")
    print("  POST   /tasks/<id>/complete - Complete task")
    print("  DELETE /tasks/<id>         - Delete task")
    print("\n")
    app.run(debug=True, host='0.0.0.0', port=5000)