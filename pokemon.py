import requests
import random
import json
import os

BASE_URL = "https://pokeapi.co/api/v2/"
JSON_FILE = "pokemons.json"

def get_pokemon_list(limit=20, offset=0):
    """
    Retrieves a list of Pokémon from the PokeAPI.
    """
    url = f"{BASE_URL}pokemon?limit={limit}&offset={offset}"
    response = requests.get(url)
    response.raise_for_status()
    data = response.json()
    return [pokemon['name'] for pokemon in data['results']]

def choose_random_pokemon(pokemon_list):
    """
    Chooses a random Pokémon from a list.
    """
    return random.choice(pokemon_list)

def get_pokemon_details(pokemon_name):
    """
    Retrieves details for a specific Pokémon from the PokeAPI.
    """
    url = f"{BASE_URL}pokemon/{pokemon_name}"
    response = requests.get(url)
    response.raise_for_status()
    return response.json()

def extract_relevant_details(pokemon_data):
    """
    Extracts relevant fields from the full Pokémon API data.
    """
    return {
        "name": pokemon_data["name"],
        "height": pokemon_data["height"],
        "weight": pokemon_data["weight"]
    }

def load_pokemon_db():
    """
    Loads the Pokémon database from a JSON file.
    """
    if os.path.exists(JSON_FILE):
        with open(JSON_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_pokemon_db(data):
    """
    Saves the Pokémon database to a JSON file.
    """
    with open(JSON_FILE, 'w') as f:
        json.dump(data, f, indent=4)

if __name__ == '__main__':
    pokemon_db = load_pokemon_db()

    while True:
        user_input = input("Would you like to draw a Pokémon? (yes/no): ").lower()
        
        if user_input == "yes":
            pokemon_list = get_pokemon_list()
            random_pokemon = choose_random_pokemon(pokemon_list)

            if random_pokemon in pokemon_db:
                print("\nPokémon already exists in DB!\n")
                details = pokemon_db[random_pokemon]
            else:
                details_raw = get_pokemon_details(random_pokemon)
                details = extract_relevant_details(details_raw)
                pokemon_db[random_pokemon] = details
                save_pokemon_db(pokemon_db)

            print(f"\n🎉 Congratulations! You drew: {random_pokemon.capitalize()}\n")
            print("Pokémon Details:")
            print(json.dumps(details, indent=4))
            print("\n")

        elif user_input == "no":
            print("Goodbye! 👋")
            break

        else:
            print("Invalid input. Please enter 'yes' or 'no'.\n")

