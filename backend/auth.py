from flask import request, jsonify
from werkzeug.security import check_password_hash
from functools import wraps
from datetime import datetime, timedelta
import jwt
from models import User
from config import SECRET_KEY

# JWT token required decorator
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        # JWT is passed in the request header
        if 'Authorization' in request.headers:
            token = request.headers['Authorization'].split(" ")[1]
        # Return 401 if token is not passed
        if not token:
            return jsonify({'message': 'Token is missing'}), 401

        try:
            # Decoding the JWT
            data = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
            current_user = User.query.filter_by(id=data['user_id']).first()
            if current_user is None:
                return jsonify({'message': 'Invalid token'}), 401
        except:
            return jsonify({'message': 'Invalid token'}), 401
        # Returns the current logged in user context to the routes
        return f(current_user, *args, **kwargs)

    return decorated

def login():
    auth = request.json
    if not auth or not auth.get('username') or not auth.get('password'):
        return jsonify({'message': 'Could not verify', 'error': 'Login required'}), 401

    user = User.query.filter_by(username=auth.get('username')).first()

    if not user:
        return jsonify({'message': 'User not found', 'error': 'Invalid credentials'}), 401

    if check_password_hash(user.password, auth.get('password')):
        # Generate JWT token
        token = jwt.encode({
            'user_id': user.id,
            'exp': datetime.utcnow() + timedelta(hours=24)
        }, SECRET_KEY, algorithm="HS256")

        return jsonify({
            'token': token,
            'user': {
                'id': user.id,
                'username': user.username
            }
        }), 200

    return jsonify({'message': 'Could not verify', 'error': 'Invalid credentials'}), 401
