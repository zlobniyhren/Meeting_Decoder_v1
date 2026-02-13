#!/bin/bash

# Тестовый скрипт для обработки одного видео файла
# Использует существующее видео из папки Whisper

WHISPER_PATH="/Users/evgenijharitonenko/Вайбкодинг/Whisper/build/bin/whisper-cli"
VIDEO_INPUT_DIR="/Users/evgenijharitonenko/Вайбкодинг/Meeting decoder/CascadeProjects/windsurf-project/video_input"
AUDIO_OUTPUT_DIR="/Users/evgenijharitonenko/Вайбкодинг/Meeting decoder/CascadeProjects/windsurf-project/audio_output"
TEXT_OUTPUT_DIR="/Users/evgenijharitonenko/Вайбкодинг/Meeting decoder/CascadeProjects/windsurf-project/text_output"

echo "🧪 Тестирование обработки видео..."

# Берем тестовое видео из папки Whisper
TEST_VIDEO="/Users/evgenijharitonenko/Вайбкодинг/Whisper/2026-01-30 14-04-43.mp4"

if [ ! -f "$TEST_VIDEO" ]; then
    echo "❌ Тестовый видео файл не найден: $TEST_VIDEO"
    exit 1
fi

# Копируем видео в папку для обработки
cp "$TEST_VIDEO" "$VIDEO_INPUT_DIR/"
VIDEO_FILE="$VIDEO_INPUT_DIR/2026-01-30 14-04-43.mp4"

filename=$(basename "$VIDEO_FILE")
name_without_ext="${filename%.*}"
audio_file="$AUDIO_OUTPUT_DIR/${name_without_ext}.wav"
text_file="$TEXT_OUTPUT_DIR/${name_without_ext}.txt"

echo "🎬 Обрабатываю видео: $filename"

# Извлекаем аудио
echo "🎵 Извлекаю аудио..."
ffmpeg -i "$VIDEO_FILE" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$audio_file" -y -loglevel error

if [ $? -eq 0 ]; then
    echo "✅ Аудио успешно извлечено: $(basename "$audio_file")"
    
    # Распознаем речь
    echo "🤖 Распознаю речь с помощью Whisper..."
    "$WHISPER_PATH" -m "/Users/evgenijharitonenko/Вайбкодинг/Whisper/models/ggml-small.bin" -f "$audio_file" -of "$TEXT_OUTPUT_DIR/${name_without_ext}" -t 8
    
    if [ $? -eq 0 ]; then
        echo "✅ Текст успешно сохранен: $(basename "$text_file")"
        echo "📊 Статистика:"
        echo "   - Размер видео: $(du -h "$VIDEO_FILE" | cut -f1)"
        echo "   - Размер аудио: $(du -h "$audio_file" | cut -f1)"
        echo "   - Размер текста: $(du -h "$text_file" | cut -f1)"
        echo "   - Длительность аудио: $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null | cut -d. -f1) сек"
        
        echo ""
        echo "📝 Первые 10 строк распознанного текста:"
        head -10 "$text_file"
        
    else
        echo "❌ Ошибка при распознавании речи"
    fi
else
    echo "❌ Ошибка при извлечении аудио"
fi

echo ""
echo "✅ Тест завершен!"
