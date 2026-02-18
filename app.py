from flask import Flask, render_template, request, session, redirect, url_for
from openai import AzureOpenAI
import os
import re
from dotenv import load_dotenv

load_dotenv()

# ======= PHOTO CONFIGURATION =======
# Add your photo URLs here. The bot will display these when users ask for photos.
# Format: "label": "url"
PHOTOS = {
    "profile": "https://example.com/bala-profile.jpg",
    "family": "https://example.com/bala-family.jpg",
    "horse riding": "https://example.com/bala-horse-riding.jpg",
    "at work": "https://example.com/bala-at-work.jpg",
    "nature": "https://example.com/bala-nature.jpg",
}
# ====================================

# Azure AI Foundry endpoint and key
AZURE_OPENAI_KEY = os.getenv("AZURE_OPENAI_API_KEY")
AZURE_OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")

# Create Azure OpenAI client with API key auth
chat_client = AzureOpenAI(
    api_key=AZURE_OPENAI_KEY,
    api_version="2024-12-01-preview",
    azure_endpoint=AZURE_OPENAI_ENDPOINT,
)


def replace_photo_markers(text):
    """Replace [PHOTO:label] markers with <img> HTML tags."""
    def replacer(match):
        label = match.group(1).strip().lower()
        url = PHOTOS.get(label)
        if url:
            return (
                f'<div class="photo-container">'
                f'<img src="{url}" alt="Bala - {label}" class="chat-photo">'
                f'<p class="photo-caption">{label.title()}</p>'
                f'</div>'
            )
        return match.group(0)  # Keep original if label not found

    return re.sub(r'\[PHOTO:(.*?)\]', replacer, text)


app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", os.urandom(24))

# Register Jinja filter so chat history also renders photo markers
app.jinja_env.filters['replace_photos'] = replace_photo_markers

@app.route("/", methods=["GET", "POST"])
def chat():
    if "messages" not in session:
        session["messages"] = [
            {
                "role": "system",
                "content": (
                    "You are Bala's personal chatbot. Your job is to answer questions about Bala in a friendly, "
                    "conversational tone. Use ONLY the following information to answer. If someone asks something "
                    "not covered below, politely say you don't have that information and suggest they reach out to Bala directly.\n\n"
                    "=== About Bala ===\n"
                    "Full Name: Bala Thimma Reddy\n"
                    "Preferred Name: Bala\n"
                    "Birth Place: Hosur Village, Kurnool District\n"
                    "Current Location: Hyderabad\n"
                    "Profession: Azure Cloud and AI Architect\n"
                    "Skills & Technologies: Cloud Computing, DevOps, Enterprise IT Architecture using Cloud and AI\n"
                    "Education: MScIT, MBA\n"
                    "Hobbies: Chess, Dance, Music, Reading, Yoga\n"
                    "Bala is living with his wife and two kids. He is passionate about leveraging technology to solve complex problems and is always eager to learn and share knowledge with others.\n"
                    "In free time Bala enjoys small trips with family especially to hill stations, beaches and historical places. He also enjoy horse riding.\n"
                    "Horse riding is one of Bala's favorite hobbies. As of now I can do horse riding at beginner level upto trauting. I am planning to take horse riding classes to learn up to gallopping.\n"
                    "I am also passionate about nature and improving nature with good plantation like, fruits, coconut, flowers, oxygen plants etc. \n"
                    "=================\n\n"
                    "\n=== Available Photos ===\n"
                    "You have the following photos you can share. When a user asks to see a photo, "
                    "include the marker [PHOTO:label] in your response (use the exact label from below). "
                    "You can include multiple photos. Always add a friendly description along with the photo.\n"
                    + "\n".join(f"- {label}" for label in PHOTOS.keys()) + "\n"
                    "========================\n\n"
                    "Always refer to Bala in third person unless the user asks 'tell me about yourself', in which case "
                    "respond as if you are introducing Bala. Keep answers concise and warm."
                )
            }
        ]

    response_text = ""

    if request.method == "POST":
        user_input = request.form.get("user_input", "").strip()
        if user_input:
            # Add user message
            session["messages"].append({"role": "user", "content": user_input})

            # Call Azure AI Foundry
            response = chat_client.chat.completions.create(
                model="gpt-4o",
                messages=session["messages"]
            )

            assistant_reply = response.choices[0].message.content
            session["messages"].append({"role": "assistant", "content": assistant_reply})
            session.modified = True

            # Replace [PHOTO:label] markers with actual image HTML
            response_text = replace_photo_markers(assistant_reply)

    return render_template("index.html", response=response_text, history=session["messages"])

@app.route("/reset", methods=["POST"])
def reset():
    session.pop("messages", None)
    return redirect(url_for("chat"))

if __name__ == "__main__":
    app.run(debug=True)
