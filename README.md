# 💊 C0: AI-Powered Amino Spiking Detector & Food Analyzer 🧪

C0 is a cutting-edge mobile application built with Flutter 💙 designed to combat deceptive practices in the supplement industry. It empowers fitness enthusiasts to verify the authenticity of whey protein supplements by detecting "amino spiking"—the unethical practice of adding low-cost amino acids to artificially inflate total protein content. 🛡️

## 🚀 Key Features

- 🤖 AI Ingredient Analysis: Uses advanced NLP to scan labels and flag suspicious additives like Glycine, Taurine, and Creatine.
- 🔍 Real-Time OCR Scanning: Instantly extracts complex ingredient lists from product images using Google MLKit.
- 📊 Nutrition Tracking: A smart, integrated food logger to monitor daily macronutrients and calories.
- 🇲🇾 Malaysian Market Focus: Tailored database to recognize local supplement brands and unique Malaysian food portions.
- 🏗️ MVVM Architecture: Engineered for high scalability and clean code maintainability.

## AI & Model Training
🛠️ Methodology

1. 📸 Text Extraction: Google MLKit OCR captures raw, often messy text from curved supplement tubs.

2. 🧹 Preprocessing: A custom TextPreprocessorService cleans the noise, handles special characters, and prepares the "text tensor" for the model.

3. ⚖️ Classification: The DistilBERT model identifies semantic patterns typical of nitrogen-spiking agents (e.g., specific clusters of amino acids).

4. 📱 Deployment: Trained in Python/PyTorch, then optimized into TensorFlow Lite (TFLite) for lightning-fast, on-device inference without needing a server.

📈 Training Specifics


- 🏗️ Architecture: DistilBERT (Lightweight Transformer).
- 💻 Platform: Trained using Hugging Face Transformers; deployed via TFLite.

- 🧠 Contextual Logic: Specifically trained to distinguish between naturally occurring aminos and "spiked" inflation profiles.

- ⚡ Performance: Optimized to deliver deep analysis results in under 5 seconds.


## 🛠️ Technical Stack

- 🎨 Frontend: Flutter & Dart

- 🔥 Backend: Firebase (Auth, Firestore, Cloud Storage)

- 🧠 AI/ML: DistilBERT NLP & Google MLKit OCR

- 🌐 APIs: Open Food Facts API

📖 How to Run
-
To get a local copy up and running, follow these steps:

```bash
# 1. Clone the repository
git clone https://github.com/faiz03-glicth/cal0appv2.git

# 2. Install dependencies
flutter pub get

# 3. Setup Firebase
# Place your 'google-services.json' in /android/app/

# 4. Run the app
flutter run
```
