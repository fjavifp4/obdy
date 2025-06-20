# Obdy: Mobile Application for Optimizing Maintenance and Monitoring of Vehicles Lacking Advanced Assistance Systems

## Abstract

Obdy is a platform designed to bring preventive maintenance and diagnostic capabilities to vehicles that lack advanced telematics. The project arises from the need detected in an ageing vehicle fleet whose owners have no reliable data on mechanical condition and no structured service reminders.

The main objective was to create an intuitive mobile application that, connected to a Bluetooth OBD‑II adapter and to its own backend, enables users to visualise real‑time parameters, log trips, manage maintenance histories, interpret fault codes, and obtain contextual assistance all within a single environment.

The solution consists of a FastAPI backend in Python with a MongoDB database and a cross‑platform Flutter app written in Dart. Clean Architecture and the BLoC pattern were followed, and a language model was integrated via API to analyse manuals and provide conversational assistance. Validation included code‑level tests, user testing, and trials on real vehicles with different adapters, demonstrating that the operational objectives were met.

The result is a functional, thoroughly tested system that fulfils the specified requirements and goals. Obdy delivers an accessible tool that enhances safety and reduces costs by enabling informed maintenance decisions, while providing a robust, modular foundation open to future extensions and improvements.

## Key Features

* Real‑time vehicle telemetry via Bluetooth OBD‑II
* Automatic trip logging with GPS
* Maintenance scheduler with history and reminders
* Fault‑code reading and plain‑language explanations
* AI‑driven contextual assistance based on workshop manuals
* Cross‑platform Flutter application (Android & iOS)
* FastAPI backend with MongoDB
* Clean Architecture & BLoC pattern implementation
* Fully tested with CI pipeline

## Minimum Requirements

### Mobile Device

| Platform    | Minimum OS                        |
| ----------- | --------------------------------- |
| **iOS**     | iOS 12 or later                   |
| **Android** | Android 4.1 (Jelly Bean) or later |

### App Permissions

* **Bluetooth** — communicate with the OBD‑II adapter
* **Location (GPS)** — log trips and locate service stations
* **Storage** — upload workshop manuals
* **Internet access** — authentication, server sync, external services

### Additional Hardware

* **Bluetooth OBD‑II adapter** — required for vehicle diagnostics and monitoring

## Running the API Locally

> In production the server is hosted remotely, but you can spin up the backend on your own machine for development or testing.

### Prerequisites

* **Python 3.x**
* **MongoDB** (local instance or Atlas cluster)
* **Git** (optional, for cloning the repository)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/fjavifp4/tfg.git
cd tfg/backend

# 2. Create & activate a virtual environment
python -m venv venv
# Windows
.\venv\Scripts\activate
# Linux / macOS
source venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt
```

### Configuration

Create a `.env` file in `backend/` with the following keys:

```
DATABASE_URL="mongodb+srv://..."
SECRET_KEY="your_secret_key_here"
ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES=60
OPENROUTER_API_KEY="your_openrouter_apikey"
OPENROUTER_URL="https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODEL="deepseek/deepseek-r1-distill-llama-70b:free"
TEST_DATABASE_URL="mongodb+srv://..."
```

### Start the Server

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

The API will now be available at `http://localhost:8000/`.

## Pointing the Mobile App to Your Local Server

If you decide to run the backend locally, you must rebuild the Flutter application with the base URL set to your server’s address:

1. Edit `tfg/car_app/lib/data/datasource/api_config.dart` and update the `baseUrl` constant to `http://<SERVER_IP>:8000`.
2. Build a new APK:

   ```bash
   flutter build apk
   ```
3. Install the generated APK on your Android device (or rebuild for iOS).
