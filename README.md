# Kibble -- My Dog Ate My Homework
Kibble is a productivity app, where the user creates tasks that need to be completed. In order to complete a task, the user must upload an image of the task being done as "proof" of completion. Once the task is completed, it becomes converted to food (kibble) that can be fed to the dog for it to live and grow. The more kibble the dog is fed, the more it grows.

## Architecture
```
┌─────────────────┐
│   Flutter App   │  ← UI, Photo Gallery, User Interactions
│   (Mobile)      │
└────────┬────────┘
         │ HTTP/REST API
         ↓
┌─────────────────┐
│   Flask Server  │  ← Processing requests, Photo Processing
│   (Python)      │
└────────┬────────┘
         │ boto3
         ↓
┌─────────────────────────────┐
│      AWS Services           │
│  ┌──────────┐  ┌─────────┐ │
│  │ DynamoDB │  │   S3    │ │
│  │(Tasks &  │  │(Photos) │ │
│  │DogState) │  │         │ │
│  └──────────┘  └─────────┘ │
└─────────────────────────────┘
```

### Data Flow

1. User takes uploads photo from gallery
2. Photo encoded to base64 and sent to Flask API
3. Flask uploads photo to S3 bucket
4. S3 returns public URL
5. Task marked complete in DynamoDB with photo URL
6. The dog is fed and grows based on the progress bar

## Tech Stack

### Frontend
- **Flutter/Dart** - Cross-platform mobile UI
- **image_picker** - Photo integration
- **http** - API communication

### Backend
- **Python/Flask** - REST API server
- **boto3** - AWS SDK for Python
- **flask-cors** - Cross-origin resource sharing

### Cloud Infrastructure
- **AWS DynamoDB** - NoSQL database for tasks and dog state
  - `Tasks` table: Stores task data and photo URLs
- **AWS S3** - Object storage for uploaded photos
- **IAM** - Access management and permissions

## Setup Instructions

### Backend -- Necessary AWS credentials required

1. **Install Python dependencies**
```bash
cd task-api
pip install flask flask-cors boto3
```

2. **Configure AWS credentials**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

3. **Run Flask server**
```bash
python dynamo_app.py
```
Server runs at `http://localhost:5000`

### Frontend (must be run in MacOS, and in a separate terminal from backend)

1. **Install Flutter dependencies**
```bash
cd mobile
flutter pub get
```

2. **Verify Flutter installation**
```bash
flutter doctor
```

3. **Open iOS Simulator**
```bash
open -a Simulator
```

4. **Run Flutter app**
```bash
flutter run -d "iPhone SE (3rd generation)" \
  --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

## API Endpoints

### Task Management
- `GET /tasks` - Get all tasks
- `POST /tasks` - Create new task
- `POST /tasks/<id>/complete` - Complete task with photo upload
- `DELETE /tasks/<id>` - Delete task

### Utilities
- `POST /seed-data` - Add sample tasks and initialize dog

## Lessons Learned

- AWS IAM permissions and credential management
- Flutter camera integration and base64 encoding
- REST API design for mobile clients
- Real-time state synchronization between mobile and cloud

## Team

- **Enas Salloum [<ens227@lehigh.edu>]** - [Frontend Developer/Integrator with Backend]  
- **Faatiha Kalam [<fak227@lehigh.edu>]** - [Backend Developer/Image Designer]
- **Kemith Perera [<kep428@lehigh.edu>]** - [Backend Developer/Helper with Frontend]
