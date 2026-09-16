import os
import re
import json
from google.cloud import firestore
import firebase_admin
from firebase_admin import credentials

def initialize_firestore(service_account_path):
    if not firebase_admin._apps:
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred)
    return firestore.Client()

def find_placeholder_courses(db):
    """
    Finds courses that look like placeholders:
    - Title matches patterns like 'Economics topic 5-60' or 'topic X-XX'
    - Missing thumbnail_url
    - Missing or extremely short body content
    """
    print("Scanning 'public_courses' collection...")
    courses_ref = db.collection('public_courses')
    # If the database is huge, we might need to stream. 
    # For now, fetching all to analyze in memory.
    docs = courses_ref.stream()
    
    placeholders = []
    
    # Regex to detect lazy serial titles like "Economics topic 5-60"
    serial_pattern = re.compile(r'topic\s*\d+-\d+', re.IGNORECASE)
    
    for doc in docs:
        data = doc.to_dict()
        title = data.get('title', '')
        thumbnail = data.get('cover_image_url') or data.get('thumbnail_url')
        body = data.get('body', '')
        
        is_placeholder = False
        reasons = []
        
        if serial_pattern.search(title):
            is_placeholder = True
            reasons.append(f"Serial title detected: '{title}'")
            
        if not thumbnail:
            is_placeholder = True
            reasons.append("Missing thumbnail")
            
        if not body or len(body.strip()) < 50:
            is_placeholder = True
            reasons.append("Empty or very short content")
            
        if is_placeholder:
            placeholders.append({
                "id": doc.id,
                "title": title,
                "reasons": reasons,
                "data": data
            })
            
    return placeholders

def find_placeholder_quizzes(db):
    """
    Finds quizzes that look like placeholders:
    - Missing thumbnail
    - Questions contain lazy dummy options like 'Option A', 'Option B'
    """
    print("Scanning 'tests' (quizzes) collection...")
    quizzes_ref = db.collection('tests')
    docs = quizzes_ref.stream()
    
    placeholders = []
    serial_pattern = re.compile(r'topic\s*\d+-\d+', re.IGNORECASE)
    
    for doc in docs:
        data = doc.to_dict()
        title = data.get('title', '')
        thumbnail = data.get('thumbnail_url')
        questions = data.get('questions', [])
        
        is_placeholder = False
        reasons = []
        
        if serial_pattern.search(title):
            is_placeholder = True
            reasons.append(f"Serial title detected: '{title}'")
            
        if not thumbnail:
            is_placeholder = True
            reasons.append("Missing thumbnail")
            
        # Check for dummy questions
        has_dummy_questions = False
        if isinstance(questions, list):
            for q in questions:
                options = q.get('options', [])
                if any(opt.lower() in ['option a', 'option b', 'a', 'b', 'c', 'd'] for opt in options):
                    has_dummy_questions = True
                    break
        elif isinstance(questions, str):
            # Sometimes stored as JSON string
            if "Option A" in questions or "Option B" in questions:
                has_dummy_questions = True
                
        if has_dummy_questions:
            is_placeholder = True
            reasons.append("Contains dummy 'Option A/B' questions")
            
        if is_placeholder:
            placeholders.append({
                "id": doc.id,
                "title": title,
                "reasons": reasons,
                "data": data
            })
            
    return placeholders

def generate_reformed_course(placeholder_data):
    """
    Placeholder for the LLM call that will generate real content.
    This will integrate with Anthropic/Gemini to fetch actual content based on the curriculum.
    """
    # TODO: Connect to LLM API, fetch real syllabus context, generate real markdown/JSON
    pass

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Audit and Reform Placeholder Courses")
    parser.add_argument("--key", required=True, help="Path to Firebase Service Account JSON")
    args = parser.add_argument()
    
    args = parser.parse_args()
    
    db = initialize_firestore(args.key)
    
    print("--- STARTING COURSE AUDIT ---")
    bad_courses = find_placeholder_courses(db)
    print(f"Found {len(bad_courses)} placeholder courses.")
    for c in bad_courses[:5]:
        print(f" - [{c['id']}] {c['title']} ({', '.join(c['reasons'])})")
        
    print("\n--- STARTING QUIZ AUDIT ---")
    bad_quizzes = find_placeholder_quizzes(db)
    print(f"Found {len(bad_quizzes)} placeholder quizzes.")
    for q in bad_quizzes[:5]:
        print(f" - [{q['id']}] {q['title']} ({', '.join(q['reasons'])})")
        
    print("\nAudit complete. Next step: Hook up LLM to rewrite and update these documents.")
