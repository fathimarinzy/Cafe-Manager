from flask import Blueprint, request
from auth import login

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/api/login', methods=['POST'])
def auth_login():
    return login()