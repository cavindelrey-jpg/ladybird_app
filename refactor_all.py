import os
import re

repo_dir = 'lib/repositories'
files = [f for f in os.listdir(repo_dir) if f.endswith('_repository.dart')]

for f in files:
    path = os.path.join(repo_dir, f)
    with open(path, 'r') as file:
        content = file.read()
        
    if 'LocalDatabase' in content:
        continue
        
    # Inject imports
    imports = "import '../data/local_database.dart';\nimport '../services/connectivity_service.dart';\n"
    content = re.sub(r'^(import .*;)', r'\1\n' + imports, content, count=1, flags=re.MULTILINE)
    
    # We will do a simple regex for supabase fetching:
    # final response = await _supabase.from('some_table').select(...);
    # This is too complex for regex. We'll leave the script here as a placeholder 
    # but the real work will be done by the agent.
    
    with open(path, 'w') as file:
        file.write(content)

print("Imports injected.")
