#!/data/data/com.termux/files/usr/bin/bash
set -e

echo ">>> [1/5] 创建目录结构..."

mkdir -p ~/ndkbox_automation/automation/templates
mkdir -p ~/ndkbox_automation/automation/screenshots
mkdir -p ~/ndkbox_automation/automation/utils

echo ">>> [2/5] 写入主程序 main.py..."

cat > ~/ndkbox_automation/automation/main.py << 'EOF'
import os
from utils.logger import log
from utils.adb_autoconnect import adb_connect
from utils.uiauto import launch_app, tap_button
from utils.ocr import extract_text
from utils.template_match import match_template

def main():
    log("自动化程序开始")
    adb_connect()
    launch_app("com.example.targetapp")
    pos = match_template("templates/reward_button.png", threshold=0.85)
    if pos:
        tap_button(pos)
    else:
        log("未检测到匹配按钮")
    text = extract_text("screenshots/current.png")
    log(f"识别到的文字: {text}")

if __name__ == "__main__":
    main()
EOF

echo ">>> 写入配置文件 config.json..."
cat > ~/ndkbox_automation/automation/config.json << 'EOF'
{
  "screenshot_path": "automation/screenshots/current.png",
  "template_path": "automation/templates/reward_button.png",
  "package_name": "com.example.targetapp"
}
EOF

echo ">>> 写入配置加载模块 config.py..."
cat > ~/ndkbox_automation/automation/config.py << 'EOF'
import json
import os

def load_config():
    path = os.path.join(os.path.dirname(__file__), "config.json")
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)
EOF

echo ">>> 写入 requirements.txt..."
cat > ~/ndkbox_automation/automation/requirements.txt << 'EOF'
opencv-python
numpy
pytesseract
EOF

echo ">>> 写入 templates/template_readme.txt..."
cat > ~/ndkbox_automation/automation/templates/template_readme.txt << 'EOF'
请将 reward_button.png 放在此目录中用于图像识别。
EOF

echo ">>> [3/5] 写入 utils/logger.py..."
cat > ~/ndkbox_automation/automation/utils/logger.py << 'EOF'
import time

def log(message):
    timestamp = time.strftime("[%Y-%m-%d %H:%M:%S]")
    print(f"{timestamp} {message}")
EOF

echo ">>> 写入 utils/adb_autoconnect.py..."
cat > ~/ndkbox_automation/automation/utils/adb_autoconnect.py << 'EOF'
import os
from .logger import log

def adb_connect():
    result = os.system("adb start-server")
    if result != 0:
        log("ADB 启动失败")
    else:
        log("ADB 启动成功")

    connected = os.system("adb devices | grep -w device")
    if connected != 0:
        log("设备未连接，尝试连接...")
        os.system("adb connect 127.0.0.1:5555")
    else:
        log("ADB 设备已连接")
EOF

echo ">>> 写入 utils/uiauto.py..."
cat > ~/ndkbox_automation/automation/utils/uiauto.py << 'EOF'
import os
from .logger import log

def launch_app(package_name):
    log(f"启动应用: {package_name}")
    os.system(f"adb shell monkey -p {package_name} -c android.intent.category.LAUNCHER 1")

def tap_button(coords):
    x, y = coords
    log(f"点击位置: ({x}, {y})")
    os.system(f"adb shell input tap {x} {y}")
EOF

echo ">>> 写入 utils/ocr.py..."
cat > ~/ndkbox_automation/automation/utils/ocr.py << 'EOF'
import pytesseract
import cv2
from .logger import log

def extract_text(image_path):
    log(f"OCR 识别图片: {image_path}")
    image = cv2.imread(image_path)
    if image is None:
        log("读取图片失败")
        return ""
    text = pytesseract.image_to_string(image)
    return text.strip()
EOF

echo ">>> 写入 utils/template_match.py..."
cat > ~/ndkbox_automation/automation/utils/template_match.py << 'EOF'
import cv2
import numpy as np
import os
from .logger import log
from automation.config import load_config

def match_template(template_path, threshold=0.85):
    config = load_config()
    screenshot = config["screenshot_path"]
    log(f"匹配模板: {template_path} 到截图: {screenshot}")

    os.system(f"adb shell screencap -p /sdcard/screen.png")
    os.system(f"adb pull /sdcard/screen.png {screenshot}")

    img = cv2.imread(screenshot, 0)
    template = cv2.imread(template_path, 0)

    if img is None or template is None:
        log("图像加载失败")
        return None

    res = cv2.matchTemplate(img, template, cv2.TM_CCOEFF_NORMED)
    min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(res)
    log(f"匹配得分: {max_val}")
    if max_val >= threshold:
        log("匹配成功")
        return max_loc
    else:
        log("匹配失败")
        return None
EOF

echo ">>> [4/5] 写入 install_automation.sh..."
cat > ~/ndkbox_automation/install_automation.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[*] 安装 Python 与依赖..."
pkg install -y python git
pip install -r ~/ndkbox_automation/automation/requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

echo "[*] 设置执行权限..."
chmod +x ~/ndkbox_automation/run.sh

echo "[*] 安装完成。请执行 ./run.sh 启动自动化程序。"
EOF

chmod +x ~/ndkbox_automation/install_automation.sh

echo ">>> 写入 run.sh..."
cat > ~/ndkbox_automation/run.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/automation"
python main.py
EOF

chmod +x ~/ndkbox_automation/run.sh

echo ">>> [5/5] 自动执行依赖安装..."
bash ~/ndkbox_automation/install_automation.sh

echo ">>> 所有生成完毕，系统已准备完毕。可执行 ./run.sh 启动。"