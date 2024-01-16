#!/bin/bash
sudo apt-get update
sudo apt-get install python3 -y
sudo apt-get install pip -y

# Install Flask app requirements
sudo pip install Flask cryptography