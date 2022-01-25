FROM debian
RUN apt update 
RUN apt install -y iputils-ping net-tools iproute2 iperf 
RUN apt install -y apache2 
RUN apt install -y apache2-utils 
RUN apt clean 
COPY index.html /var/www/html/
EXPOSE 80 
CMD ["apache2ctl", "-D", "FOREGROUND"]
