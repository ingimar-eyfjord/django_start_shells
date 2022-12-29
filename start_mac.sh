#!/bin/bash

#set $SETTINGS_FILE variable to full path of the your django project settings.py file

# checks that app $1 is in the django project settings file
project_name=''
app_name=''
docker_compose_answer=''
tailwind_answer=''
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
        sed -i -e '1h;2,$H;$!d;g' -re "s/(INSTALLED_APPS\s?=\s?\[[\n '._a-zA-Z,]*)/\1    '$1',\n/1" $SETTINGS_FILE

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
    npm --prefix ./$1/ install -D tailwindcss@latest postcss@latest autoprefixer@latest
    npx --prefix ./$1/ tailwind init
    tee -a ./$1/tailwind.config.js <<EOF
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
    tee -a ./$1/static/css/style.css <<EOF
"@tailwind base;
@tailwind components;
@tailwind utilities;"
EOF
    ### add tailwind to webpack.mix.js
    tee -a ./$1/webpack.mix.js <<EOF
"const mix = require('laravel-mix');
mix.postCss('./$1/static/css/style.css', './$1/static/css', [
    require('tailwindcss'),
]);"
EOF

#   "scripts": {
#     "start": "npx tailwindcss -i ./static/src/input.css -o ./static/src/output.css --watch"
#   },
### ! add tailwind start script to package.json after first bracket

    sed -i '' -e '1h;2,$H;$!d;g' -re 's|({)|\1 \n"scripts": {\n"start": "npx tailwindcss -i ./static/src/input.css -o ./static/src/output.css --watch"\n},|1' ./$1/package.json



    ### add tailwind to index.html
    # sed -i -e '1h;2,$H;$!d;g' -re "s/(<head>)/\1

    # <link rel='stylesheet' href='{% static 'css/style.css' %}'>
    # <script src='https://cdnjs.cloudflare.com/ajax/libs/jquery/3.5.1/jquery.min.js'></script>
    # <script src='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.5.3/js/bootstrap.min.js'></script>
    # <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.5.3/css/bootstrap.min.css'>
    # <script src='https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.1/js/all.min.js'></script>
    # <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.1/css/all.min.css'>/g" ./$app_name/templates/index.html

}

set_up_docker_compose(){
    echo "setting up docker compose"
    touch docker-compose.yml
    tee -a docker-compose.yml <<"EOF"
version: "3.8"

services:

    app:
        build: .
        ports:
            - 8080:8080
            - 8000:8000
        env_file:
            - ${RTE}.env
        volumes:
            - .:/app/
            - static:/static/
            - media:/media/
        networks:
            - es-net

volumes:
    static:
    media:

networks:
  es-net:
    driver: bridge
EOF
}

set_up_docker() {
    echo "setting up docker"
    echo "do you want to docker compose?: [yes/no]"
    read docker_compose_answer
    if [[ $docker_compose_answer == 'yes' ]]; then
        echo "setting up docker compose"
        set_up_docker_compose
        echo 'do you want to add postgres?: [yes/no]'
        read postgres_answer
        echo 'do you want to add nginx?: [yes/no]'
        read nginx_answer
        echo 'do you want to add redis?: [yes/no]'
        read redis_answer
    fi

touch Dockerfile
tee -a Dockerfile <<"EOF"
FROM python:3.8.5-slim-buster
FROM python:3.9-slim-buster

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y libpq-dev python3-dev python-dev python-psycopg2 python3-psycopg2 gcc xz-utils curl


EOF
# Create an entrypoint file
touch entrypoint.sh
tee -a entrypoint.sh <<"EOF"
#!/bin/sh

echo "${RTE} Runtime Environment - Running entrypoint."

if [ "$STAGE" = "install" ]; then

   pip install --upgrade pip
   pip install django gunicorn psycopg2-binary django-compressor
   pip freeze > requirements.txt
fi

if [ "$RTE" = "dev" ]; then

    ## Append tailwind script if yes
    python manage.py makemigrations --merge
    python manage.py migrate --noinput
    python manage.py runserver "$APP_IP_SCOPE":8000


elif [ "$RTE" = "test" ]; then

    echo "This is tets."

elif [ "$RTE" = "prod" ]; then

    ## Append tailwind script if yes
    python manage.py check --deploy
    python manage.py collectstatic --noinput
    gunicorn expertise_search.asgi:application -b 0.0.0.0:8080 -k uvicorn.workers.UvicornWorker

fi
EOF
echo "-------- $3"
if [[ $3 == "yes" ]]; then
echo "adding nodejs to dockerfile"
tee -a Dockerfile <<EOF
# Download latest nodejs binary
RUN curl https://nodejs.org/dist/v14.15.4/node-v14.15.4-linux-x64.tar.xz -O
# Extract & install
RUN tar -xf node-v14.15.4-linux-x64.tar.xz
RUN ln -s /node-v14.15.4-linux-x64/bin/node /usr/local/bin/node
RUN ln -s /node-v14.15.4-linux-x64/bin/npm /usr/local/bin/npm
RUN ln -s /node-v14.15.4-linux-x64/bin/npx /usr/local/bin/npx
EOF

## Add taiwind to entry point
# sed -i '' -e '1h;2,$H;$!d;g' -re "s|(## Append tailwind script if yes)|\1 \n    npm --prefix ./$app_name/ install -D tailwindcss@latest postcss@latest autoprefixer@latest\n    npx --prefix ./$app_name/ tailwind init|1" entrypoint.sh
# sed -i '' -e '1h;2,$H;$!d;g' -re "s|(## Append tailwind script if yes)|\1 \n    . start_mac.sh && install_tailwind $app_name |1" entrypoint.sh
sed -i '' -e '1h;2,$H;$!d;g' -re "s|(## Append tailwind script if yes)|\1 \n npm --prefix ./$app_name run script start |g" entrypoint.sh
fi
    
    
tee -a Dockerfile <<EOF
WORKDIR /app
COPY . /app

COPY ./entrypoint.sh /
ENTRYPOINT ["sh", "/entrypoint.sh"]
EOF

}

function install_without_docker(){
        # create a virtual environment
        python3 -m venv env
        # activate the virtual environment
        source env/bin/activate
        # install django
        pip install django
        # install compressor
        pip install django-compressor
        # create a django project
        django-admin startproject $1 .
        # create a django app
        python manage.py startapp $2
        # run migrations
        python manage.py makemigrations
        python manage.py migrate
        add_folder_structure $2
        add_urls_to_app $2
        add_view_function $2
        pip freeze > requirements.txt
        add_app2django_settings $2 $1
        if [[ $3 == "yes" ]]; then
            # check if node is installed
            if [[ $(node -v) == *"v"* ]]; then
                install_tailwind $2
                if [[ $4 == "yes" ]]; then
                    npm --prefix ./$2/ install -D @fullhuman/postcss-purgecss
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
}


if [[ "$OSTYPE" =~ ^darwin ]]; then
    echo "OSX"

    if [[ $(python3 --version) == *"Python 3"* ]]; then
        add_env_variable
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

        echo "do you want to add a git repository?: [yes/no]"
        read git_answer
        if [[ $git_answer == "yes" ]]; then
            git init
            git add .
            git commit -m "initial commit"
        else
            echo "ok skipping"
        fi
        
        echo "do you want to add docker?: [yes/no]"
        read docker_answer
        if [[ ! $docker_answer == "yes" ]]; then
        echo "Installing without docker"
        install_without_docker $project_name $app_name $tailwind_answer $purge_answer
        else
        set_up_docker $project_name $app_name $tailwind_answer $purge_answer
        fi

        # add app_name to INSTALLED_APPS in settings.py

        if [[ $server_answer == "yes" ]]; then
            # (npm --prefix ./$app_name/ run dev &)
            # python manage.py runserver

            if [[ $docker_answer == "yes" ]]; then
            if [[ $docker_compose_answer == "yes" ]]; then
                echo "starting docker-compose"
                $STAGE= "install" 
                $RTE= "dev" 
                docker-compose up
            else
                $STAGE="install" 
                $RTE="dev" 
                echo "starting docker"
                docker build -t "$project_name:Dockerfile" .
                fi
            else
                echo "starting server"
                # (npm --prefix ./$app_name/ run dev &)
                python manage.py runserver
            fi
        else
            echo "exiting"
            return
        fi

    else
        echo "Python 3 is not installed"
    fi
fi
