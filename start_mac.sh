#!/bin/bash

#set $SETTINGS_FILE variable to full path of the your django project settings.py file

# checks that app $1 is in the django project settings file
project_name=''
app_name=''

is_app_in_django_settings() {
    # checking that django project settings file exists
    if [ ! -f $2 ]; then
        echo "Error: The django project settings file '$2' does not exist"
        return
    fi
    cat $2 | grep -Pzo "INSTALLED_APPS\s?=\s?\[[\s\w\.,']*$1[\s\w\.,']*\]\n?" >/dev/null 2>&1
    # now $?=0 if app is in settings file
    # $? not 0 otherwise
}

# adds app $1 to the django project settings
add_app2django_settings() {
    SETTINGS_FILE={$2}'/settings.py'
    is_app_in_django_settings $1 SETTINGS_FILE
    if [ $? -ne 0 ]; then
        echo "Info. The app '$1' is not in the django project settings file '$SETTINGS_FILE'. Adding."
        sed -i -e '1h;2,$H;$!d;g' -re "s/(INSTALLED_APPS\s?=\s?\[[\n '._a-zA-Z,]*)/\1    '$1',\n/g" $SETTINGS_FILE
        # checking that app $1 successfully added to django project settings file
        is_app_in_django_settings $1
        if [ $? -ne 0 ]; then
            echo "Error. Could not add the app '$1' to the django project settings file '$SETTINGS_FILE'. Add it manually, then run this script again."
            return
        else
            echo "Info. The app '$1' was successfully added to the django settings file '$SETTINGS_FILE'."
        fi
    else
        echo "Info. The app '$1' is already in the django project settings file '$SETTINGS_FILE'"
    fi
}

function add_folder_structure() {
    mkdir -p $1/{templates,static/{css,js,images}}
    touch $1/templates/index.html
    touch $1/templates/_base.html

    tee -a $1/templates/index.html <<EOF
'{% extends "_base.html" %} 
{% block content %}

{% endblock content %}'
EOF

    tee -a $1/templates/_base.html <<EOF
'<!DOCTYPE html>
{% load compress %} 
{% load static %}
{% csrf_token %}
<html>
    <head>
        <title>My Project</title>
    </head>

    <body>
    {% block content %}
    {% endblock content %}
    </body>
</html>'
EOF

}

function add_env_variable() {
    echo "RTE=
APP_IP_SCOPE=0.0.0.0
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=
" | tee -a prod.env >>dev.env >>test.env
}

function add_urls_to_app() {
touch $1/urls.py
    tee -a $1/urls.py <<EOF
"from django.urls import path
from . import views

app_name = '$1'

urlpatterns = [
    path('', views.index, name='index'),
]"
EOF
}

add_view_function() {
    echo '

def index(request):
    return render(request, "index.html")' | tee -a $1/views.py
}

validate_name() {
    if [[ ! "$1" =~ ^[a-z_]+$ ]]; then
        echo "Invalid name, please use only lowercase letters and underscores."
        echo "Try again: "
        read my_var
        validate_name $my_var $2
    else
        if [[ $2 == 'project_name' ]]; then
            project_name=$1
        else
            app_name=$1
        fi
    fi

}

function install_tailwind() {
    echo "installing tailwind"
    npm --prefix ./$app_name/ install -D tailwindcss@latest postcss@latest autoprefixer@latest
    npx --prefix ./$app_name/ tailwind init
    tee -a ./$app_name/tailwind.config.js <<EOF
"module.exports" = {
    purge: [
        './**/*.html',
        './**/*.py',
    ],
    theme: {
        extend: {},
    },
    variants: {},
    plugins: [],
}
EOF
    ### add tailwind to style.css
    tee -a ./$app_name/static/css/style.css <<EOF
"@tailwind base;
@tailwind components;
@tailwind utilities;"
EOF
    ### add tailwind to webpack.mix.js
    tee -a ./$app_name/webpack.mix.js <<EOF
"const mix = require('laravel-mix');
mix.postCss('./$app_name/static/css/style.css', './$app_name/static/css', [
    require('tailwindcss'),
]);"
EOF

#   "scripts": {
#     "start": "npx tailwindcss -i ./static/src/input.css -o ./static/src/output.css --watch"
#   },
### ! add tailwind start script to package.json after first bracket

    sed -i '' -e '1h;2,$H;$!d;g' -re 's|({)|\1 \n"scripts": {\n"start": "npx tailwindcss -i ./static/src/input.css -o ./static/src/output.css --watch"\n},|1' ./$app_name/package.json



    ### add tailwind to index.html
    # sed -i -e '1h;2,$H;$!d;g' -re "s/(<head>)/\1

    # <link rel='stylesheet' href='{% static 'css/style.css' %}'>
    # <script src='https://cdnjs.cloudflare.com/ajax/libs/jquery/3.5.1/jquery.min.js'></script>
    # <script src='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.5.3/js/bootstrap.min.js'></script>
    # <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.5.3/css/bootstrap.min.css'>
    # <script src='https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.1/js/all.min.js'></script>
    # <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.1/css/all.min.css'>/g" ./$app_name/templates/index.html

        

}

if [[ "$OSTYPE" =~ ^darwin ]]; then
    echo "OSX"

    if [[ $(python3 --version) == *"Python 3"* ]]; then
        echo "Enter Django project name: "
        read project
        validate_name $project 'project_name'
        echo "Enter Django app name: "
        read app_name
        validate_name $app_name 'app_name'
        if [[ $project_name == $app_name ]]; then
            echo "Django project name and app name cannot be the same"
            echo "choose a different name for the app?: [yes/no]"
            read answer
            if [[ $answer == "yes" ]]; then
                echo "Enter Django app name: "
                read app_name
                validate_name $app_name 'app_name'
            else
                echo "exiting"
                return
            fi
        fi
        echo "do you want to install TailwindCSS?: [yes/no]"
        read tailwind_answer
        if [[ $tailwind_answer == "yes" ]]; then
            echo "do you want to install PurgeCSS?: [yes/no]"
            read purge_answer
        fi
        echo "do you want to start the server after install?: [yes/no]"
        read server_answer

        # create a virtual environment
        python3 -m venv env
        # activate the virtual environment
        source env/bin/activate
        # install django
        pip install django
        # install compressor
        pip install django-compressor
        # create a django project
        django-admin startproject $project_name .
        # create a django app
        python manage.py startapp $app_name
        # run migrations
        python manage.py makemigrations
        python manage.py migrate
        # run the django application
        add_env_variable
        add_folder_structure $app_name
        add_urls_to_app $app_name
        add_view_function $app_name
        # add app_name to INSTALLED_APPS in settings.py
        # add_app2django_settings $app_name $project_name

        if [[ $tailwind_answer == "yes" ]]; then
            # check if node is installed
            if [[ $(node -v) == *"v"* ]]; then
                install_tailwind
                if [[ $purge_answer == "yes" ]]; then
                    npm --prefix ./$app_name/ install -D @fullhuman/postcss-purgecss
                else
                    echo "ok skipping PurgeCSS"
                fi
            else
                echo "Node is not installed"
                echo "do you want to install Node?: [yes/no]"
                read node_answer
                if [[ $node_answer == "yes" ]]; then
                    brew install node
                else
                    echo "exiting"
                    return
                fi
            fi
        else
            echo "ok skipping"
        fi

        if [[ $server_answer == "yes" ]]; then
            (npm --prefix ./$app_name/ run dev &)
            python manage.py runserver
        else
            echo "exiting"
            return
        fi

    else
        echo "Python 3 is not installed"
    fi
fi
