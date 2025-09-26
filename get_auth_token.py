import requests
import json

BASE_URL = "http://localhost:5000"
USERNAME = "MaykonRodas"
PASSWORD = "maykondejavularanja12"

def get_token():
    url = f"{BASE_URL}/auth/username-login"
    headers = {"Content-Type": "application/json"}
    payload = {"username": USERNAME, "password": PASSWORD}

    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        response.raise_for_status()
        data = response.json()
        if data.get("success") and data.get("token"):
            print("Token obtido com sucesso: " + data['token'])
            return data["token"]
        else:
            print("Erro ao obter token: " + str(data.get("error", "Resposta inesperada")))
            return None
    except requests.exceptions.RequestException as e:
        print(f"Erro na requisição de login: {e}")
        if e.response is not None:
            print(f"Status Code: {e.response.status_code}")
            print(f"Response Body: {e.response.text}")
        return None

if __name__ == "__main__":
    get_token()


