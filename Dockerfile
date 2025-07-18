# Dart SDK image
FROM dart:stable AS build

# Loyihani konteynerga nusxalash
WORKDIR /app
COPY . .

# Paketlarni o‘rnatish
RUN dart pub get

# Serverni ishga tushirish
CMD ["dart", "run", "bin/new_backend.dart"] 