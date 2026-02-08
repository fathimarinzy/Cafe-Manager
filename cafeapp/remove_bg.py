
import os
from PIL import Image

def remove_background(input_path, output_path):
    try:
        img = Image.open(input_path)
        img = img.convert("RGBA")
        datas = img.getdata()

        newData = []
        for item in datas:
            # Change all white (also shades of whites)
            # Find all pixels that are white-ish (R>200, G>200, B>200)
            if item[0] > 200 and item[1] > 200 and item[2] > 200:
                newData.append((255, 255, 255, 0))
            else:
                newData.append(item)

        img.putdata(newData)
        
        # Crop the image to the non-transparent area
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
            
        img.save(output_path, "PNG")
        print(f"Successfully processed {input_path} to {output_path}")
    except Exception as e:
        print(f"Error processing image: {e}")

input_icon = r"c:\Users\rinzy\Desktop\PROJECTS\Cafe Management\cafeapp\assets\icon\icon_backup.png"
output_icon = r"c:\Users\rinzy\Desktop\PROJECTS\Cafe Management\cafeapp\assets\icon\icon.png"

# Use the backup as source since we backed it up in step 0
remove_background(input_icon, output_icon)
