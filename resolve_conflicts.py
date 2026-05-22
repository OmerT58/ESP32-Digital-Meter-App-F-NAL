import sys

def resolve(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith('<<<<<<< HEAD'):
            # we are in a conflict. We want to keep HEAD.
            i += 1
            while i < len(lines) and not lines[i].startswith('======='):
                out.append(lines[i])
                i += 1
            # skip =======
            i += 1
            while i < len(lines) and not lines[i].startswith('>>>>>>>'):
                i += 1
            # skip >>>>>>>
            i += 1
        else:
            out.append(line)
            i += 1

    with open(filename, 'w', encoding='utf-8') as f:
        f.writelines(out)

resolve('lib/screens/home_screen.dart')
resolve('lib/services/laser_tracking_service.dart')
print("Conflicts resolved.")
