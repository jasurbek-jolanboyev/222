import eventlet
eventlet.monkey_patch()

import os
import uuid
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_socketio import SocketIO, emit, join_room, leave_room
from flask_cors import CORS
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.config['SECRET_KEY'] = 'cyber_community_ultra_key_2026'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///cyber_space_v3.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = 'uploads'

# Media papkalarni strukturasi
MEDIA_TYPES = ['messages', 'posts', 'avatars', 'audio']
for m_type in MEDIA_TYPES:
    os.makedirs(os.path.join(app.config['UPLOAD_FOLDER'], m_type), exist_ok=True)

db = SQLAlchemy(app)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

# --- MODELLAR ---

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    fcm_token = db.Column(db.String(500))  # Push notification uchun
    last_seen = db.Column(db.DateTime, default=datetime.utcnow)
    is_online = db.Column(db.Boolean, default=False)

class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    sender = db.Column(db.String(80), nullable=False)
    receiver = db.Column(db.String(80), nullable=False)
    content = db.Column(db.Text)
    msg_type = db.Column(db.String(20), default='text') # text, image, file, audio
    media_url = db.Column(db.String(500))
    file_name = db.Column(db.String(200))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    is_read = db.Column(db.Boolean, default=False)

class Post(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200))
    description = db.Column(db.Text)
    media_url = db.Column(db.String(500))
    post_type = db.Column(db.String(50)) # 'video' (reels) yoki 'image'
    views = db.Column(db.Integer, default=0)
    category = db.Column(db.String(50), default='Cyber')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# --- REAL-TIME LOGIKA ---

users_sid = {} # socket_id larni saqlash uchun

@socketio.on('connect')
def handle_connect():
    print(f"Yangi qurilma ulandi: {request.sid}")

@socketio.on('join')
def handle_join(data):
    username = data.get('username')
    if username:
        join_room(username)
        users_sid[request.sid] = username
        user = User.query.filter_by(username=username).first()
        if not user:
            user = User(username=username)
            db.session.add(user)
        
        user.is_online = True
        user.last_seen = datetime.utcnow()
        db.session.commit()
        
        emit('user_status', {'username': username, 'status': 'online'}, broadcast=True)

@socketio.on('send_message')
def handle_send(data):
    sender = data.get('sender')
    receiver = data.get('receiver')
    
    # Bazaga xabarni saqlash
    new_msg = Message(
        sender=sender, 
        receiver=receiver, 
        content=data.get('content'),
        msg_type=data.get('type', 'text'),
        media_url=data.get('media_url'),
        file_name=data.get('file_name')
    )
    db.session.add(new_msg)
    db.session.commit()

    message_payload = {
        'id': new_msg.id,
        'sender': sender,
        'receiver': receiver,
        'content': new_msg.content,
        'type': new_msg.msg_type,
        'media_url': new_msg.media_url,
        'file_name': new_msg.file_name,
        'timestamp': new_msg.timestamp.isoformat(),
        'is_read': False
    }

    # Qabul qiluvchiga va yuboruvchiga uzatish
    emit('receive_message', message_payload, room=receiver)
    emit('receive_message', message_payload, room=sender)

@socketio.on('disconnect')
def handle_disconnect():
    username = users_sid.get(request.sid)
    if username:
        user = User.query.filter_by(username=username).first()
        if user:
            user.is_online = False
            user.last_seen = datetime.utcnow()
            db.session.commit()
            emit('user_status', {'username': username, 'status': 'offline', 'last_seen': user.last_seen.isoformat()}, broadcast=True)
        users_sid.pop(request.sid, None)

# --- MEDIA UPLOAD API ---

@app.route('/api/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({"error": "Fayl yo'q"}), 400
    
    file = request.files['file']
    upload_type = request.form.get('type', 'messages') # messages, posts, etc.
    
    ext = file.filename.split('.')[-1]
    filename = f"{uuid.uuid4().hex}.{ext}"
    save_path = os.path.join(app.config['UPLOAD_FOLDER'], upload_type, filename)
    file.save(save_path)
    
    return jsonify({
        "url": f"/uploads/{upload_type}/{filename}",
        "file_name": file.filename
    })

@app.route('/api/posts', methods=['GET'])
def get_posts():
    posts = Post.query.order_by(Post.created_at.desc()).all()
    return jsonify([{
        "id": p.id,
        "title": p.title,
        "mediaPath": p.media_url,
        "type": p.post_type,
        "views": p.views,
        "category": p.category,
        "description": p.description
    } for p in posts])

@app.route('/uploads/<path:filename>')
def serve_uploads(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)