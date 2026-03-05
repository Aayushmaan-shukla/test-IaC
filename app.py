from flask import Flask
import os

app = Flask(__name__)

MODE = os.getenv('MODE', 'dev')

@app.route('/')
def hello():
    return {'message': 'Hola Amigo', 'mode': MODE}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
