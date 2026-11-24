import os
import shutil

source_folder = "lib/l10n"
dest_folder = "l10n_json"

os.makedirs(dest_folder, exist_ok=True)

for filename in os.listdir(source_folder):
    if filename.endswith(".arb"):
        source_path = os.path.join(source_folder, filename)
        new_filename = filename.replace(".arb", ".json")
        dest_path = os.path.join(dest_folder, new_filename)
        
        shutil.copy2(source_path, dest_path)

print("done")