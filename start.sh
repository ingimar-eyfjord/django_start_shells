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




# check if linux system
if [[ "$OSTYPE" =~ ^linux ]]; then
    echo "Linux"
    if ! [ -x "$(command -v apt-get)" ]; then
        echo 'Error: apt-get is not installed.'
    else
        if [[ $python_version == *"Python 3"* ]]; then
            echo "Python 3 is installed"
        else
            echo "Python 3 is not installed"
            sudo apt-get install python3
            # Install pip3
            sudo apt-get install python3-pip
            # # Install virtualenv
            sudo pip3 install virtualenv
            # Create a virtual environment
            virtualenv -p python3 env
            # Activate the virtual environment
            source env/bin/activate
            # Install django
            pip3 install django
            # Create a django project
            django-admin startproject project_name
            # Create a django app
            python3 manage.py startapp app_name
            # Run the django application
            python3 manage.py runserver
            # Deactivate the virtual environment
            deactivate
        fi
    fi
fi
