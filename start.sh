#!/bin/bash

echo "🚀 Установка и запуск обработчика видео"
echo ""

# Проверяем и устанавливаем fswatch
if ! command -v fswatch &> /dev/null; then
    echo "📦 Устанавливаю fswatch для мгновенного отслеживания файлов..."
    brew install fswatch
    if [ $? -eq 0 ]; then
        echo "✅ fswatch успешно установлен"
    else
        echo "⚠️  Не удалось установить fswatch. Скрипт будет работать с проверкой каждые 5 секунд"
    fi
else
    echo "✅ fswatch уже установлен"
fi

echo ""
echo "🎥 Запускаю обработчик видео..."
echo "📂 Поместите видео файлы в папку: video_input/"
echo "⏹️  Нажмите Ctrl+C для остановки"
echo ""

# Запускаем основной скрипт
./video_processor.sh
