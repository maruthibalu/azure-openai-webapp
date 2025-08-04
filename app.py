#from flask import Flask, render_template, request
from flask import Flask, render_template, request, session, redirect, url_for
from openai import AzureOpenAI
import os
from dotenv import load_dotenv

load_dotenv()

# Load environment variables (optional: you can hardcode for now)
AZURE_OPENAI_KEY = os.getenv("AZURE_OPENAI_API_KEY")
AZURE_OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")

# Create Azure OpenAI client
client = AzureOpenAI(
    api_key=AZURE_OPENAI_KEY,
    api_version="2024-02-15-preview",  # Use the latest supported version
    azure_endpoint=AZURE_OPENAI_ENDPOINT
)

app = Flask(__name__)
app.secret_key = os.urandom(24)

@app.route("/", methods=["GET", "POST"])
def chat():
    if "messages" not in session:
     session["messages"] = [
    {
        "role": "system",
        "content": (
            "You are a helpful assistant. Use the following knowledge to answer questions:\n"
            "Q: Who is Aamuktha?\nA: Aamuktha is a good girl. She studies well and she is a good painter too.\n"
            "Q: What does Aamuktha like?\nA: Aamuktha likes painting and reading books."
        )
    }
]

    response_text = ""

    if request.method == "POST":
        user_input = request.form.get("user_input", "").strip()
        if user_input:
            # Add user message
            session["messages"].append({"role": "user", "content": user_input})

            # Call Azure OpenAI
            response = client.chat.completions.create(
                model="gpt-4.1",
                messages=session["messages"]
            )

            assistant_reply = response.choices[0].message.content
            session["messages"].append({"role": "assistant", "content": assistant_reply})
            session.modified = True

            response_text = assistant_reply

    return render_template("index.html", response=response_text, history=session["messages"])

@app.route("/reset", methods=["POST"])
def reset():
    session.pop("messages", None)
    return redirect(url_for("chat"))

if __name__ == "__main__":
    app.run(debug=True)
