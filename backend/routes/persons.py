# Create a new file: backend/routes/persons.py
from flask import Blueprint, request, jsonify
from models import db, Person
from auth import token_required
from datetime import datetime

persons_bp = Blueprint('persons', __name__)

@persons_bp.route('/api/persons', methods=['POST'])
@token_required
def create_person(current_user):
    data = request.json
    if not data:
        return jsonify({'message': 'No input data provided'}), 400
    
    # Validate person data
    required_fields = ['name', 'phoneNumber', 'place']
    if not all(field in data for field in required_fields):
        return jsonify({'message': 'Missing required fields'}), 400
    
    # Create new person
    new_person = Person(
        name=data['name'],
        phone_number=data['phoneNumber'],
        place=data['place'],
    )
    
    db.session.add(new_person)
    db.session.commit()
    
    # Format response
    response = {
        'id': str(new_person.id),
        'name': new_person.name,
        'phoneNumber': new_person.phone_number,
        'place': new_person.place,
        'dateVisited': new_person.date_visited.isoformat()
    }
    
    return jsonify(response), 201

@persons_bp.route('/api/persons', methods=['GET'])
@token_required
def get_persons(current_user):
    persons = Person.query.all()
    result = []
    
    for person in persons:
        result.append({
            'id': str(person.id),
            'name': person.name,
            'phoneNumber': person.phone_number,
            'place': person.place,
            'dateVisited': person.date_visited.isoformat()
        })
    
    return jsonify(result), 200

@persons_bp.route('/api/persons/search', methods=['GET'])
@token_required
def search_persons(current_user):
    query = request.args.get('query', '')
    if not query:
        return jsonify([]), 200
    
    # Search for persons by name
    persons = Person.query.filter(Person.name.like(f'%{query}%')).all()
    result = []
    
    for person in persons:
        result.append({
            'id': str(person.id),
            'name': person.name,
            'phoneNumber': person.phone_number,
            'place': person.place,
            'dateVisited': person.date_visited.isoformat()
        })
    
    return jsonify(result), 200