#!/bin/bash

if [[ "$OSTYPE" =~ ^Darwin ]]; then
    echo "OSX"
    if [[ $python_version == *"Python 3"* ]]; then
        echo "Python 3 is installed"
        # create a virtual environment
        python3 -m venv djngo_environment
        # activate the virtual environment
        source djngo_environment/bin/activate
        # install django
        pip install django
        # create a django project
        django-admin startproject project_name .
        # create a django app
        python manage.py startapp app_name
        # run migrations
        python manage.py makemigrations
        python manage.py migrate
        # run the django application
        python manage.py runserver
    else
        echo "Python 3 is not installed"
    fi
fi