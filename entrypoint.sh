#!/bin/sh

echo "${RTE} Runtime Environment - Running entrypoint."

if [ "$STAGE" = "install" ]; then

   pip install --upgrade pip
   pip install django gunicorn psycopg2-binary django-compressor
   pip freeze > requirements.txt
fi

if [ "$RTE" = "dev" ]; then

    ## Append tailwind script if yes 
 npm --prefix ./app run script start 
    python manage.py makemigrations --merge
    python manage.py migrate --noinput
    python manage.py runserver "$APP_IP_SCOPE":8000


elif [ "$RTE" = "test" ]; then

    echo "This is tets."

elif [ "$RTE" = "prod" ]; then

    ## Append tailwind script if yes 
 npm --prefix ./app run script start 
    python manage.py check --deploy
    python manage.py collectstatic --noinput
    gunicorn expertise_search.asgi:application -b 0.0.0.0:8080 -k uvicorn.workers.UvicornWorker

fi
