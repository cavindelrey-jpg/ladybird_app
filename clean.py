import re

with open('lib/features/dashboard/universal_home_page.dart', 'r') as f:
    content = f.read()

content = re.sub(r'  bool get _canManageHeroBanner {.*?\}', '', content, flags=re.DOTALL)
content = re.sub(r'  Future<void> _pickHeroBanner.*?\}', '', content, flags=re.DOTALL)
content = re.sub(r'  Future<void> _deleteHeroBanner.*?\}', '', content, flags=re.DOTALL)
content = re.sub(r'  Widget _resumeLearningButton.*?\}', '', content, flags=re.DOTALL)

with open('lib/features/dashboard/universal_home_page.dart', 'w') as f:
    f.write(content)
