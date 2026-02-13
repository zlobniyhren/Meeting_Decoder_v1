#!/bin/bash

# Настройки
WHISPER_PATH="/Users/evgenijharitonenko/Вайбкодинг/Whisper/build/bin/whisper-cli"
VIDEO_INPUT_DIR="/Users/evgenijharitonenko/Вайбкодинг/Meeting decoder/CascadeProjects/windsurf-project/video_input"
AUDIO_OUTPUT_DIR="/Users/evgenijharitonenko/Вайбкодинг/Meeting decoder/CascadeProjects/windsurf-project/audio_output"
TEXT_OUTPUT_DIR="/Users/evgenijharitonenko/Вайбкодинг/Meeting decoder/CascadeProjects/windsurf-project/text_output"
WHISPER_MODEL_PATH="${WHISPER_MODEL_PATH:-/Users/evgenijharitonenko/Вайбкодинг/Whisper/models/ggml-small.bin}"
WHISPER_LANG="${WHISPER_LANG:-ru}"
VAD_MODEL_PATH="/Users/evgenijharitonenko/Вайбкодинг/Whisper/models/for-tests-silero-v5.1.2-ggml.bin"
USE_VAD="${USE_VAD:-0}"

 shopt -s nullglob

function wait_for_stable_file() {
    local file_path="$1"
    local stable_checks="${2:-3}"
    local sleep_seconds="${3:-1}"

    local prev_size=""
    local same_count=0

    while true; do
        if [ ! -f "$file_path" ]; then
            return 1
        fi

        local size
        size=$(stat -f%z "$file_path" 2>/dev/null)
        if [ -z "$size" ]; then
            return 1
        fi

        if [ "$size" = "$prev_size" ]; then
            same_count=$((same_count + 1))
        else
            same_count=0
            prev_size="$size"
        fi

        if [ "$same_count" -ge "$stable_checks" ]; then
            return 0
        fi

        sleep "$sleep_seconds"
    done
}

# Функция обработки видео
function process_video() {
    local video_file="$1"
    local filename=$(basename "$video_file")
    local name_without_ext="${filename%.*}"
    local audio_file="$AUDIO_OUTPUT_DIR/${name_without_ext}.wav"
    local text_file="$TEXT_OUTPUT_DIR/${name_without_ext}.txt"
    
    echo "🎬 Обрабатываю видео: $filename"
    
    # Проверяем, не обрабатывали ли уже этот файл
    if [ -f "$text_file" ]; then
        echo "⏭️  Файл уже обработан, пропускаю: $filename"
        return
    fi
    
    echo "⏳ Жду пока файл докопируется (стабилизация размера)..."
    if ! wait_for_stable_file "$video_file" 3 1; then
        echo "❌ Не удалось дождаться стабильного файла: $video_file"
        return
    fi
    
    echo "🎵 Извлекаю аудио..."
    ffmpeg -i "$video_file" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$audio_file" -y -loglevel error
    
    if [ $? -eq 0 ]; then
        echo "✅ Аудио успешно извлечено: $(basename "$audio_file")"
        
        echo "🤖 Распознаю речь с помощью Whisper..."
        local whisper_args=(
            -m "$WHISPER_MODEL_PATH"
            -f "$audio_file"
            -of "$TEXT_OUTPUT_DIR/${name_without_ext}"
            -otxt
            -l "$WHISPER_LANG"
            -t 8
        )
        
        if [ "$USE_VAD" = "1" ]; then
            if [ -f "$VAD_MODEL_PATH" ]; then
                whisper_args+=(--vad --vad-model "$VAD_MODEL_PATH")
            else
                echo "⚠️  USE_VAD=1, но VAD модель не найдена: $VAD_MODEL_PATH"
            fi
        fi
        
        "$WHISPER_PATH" "${whisper_args[@]}"
        
        if [ $? -eq 0 ]; then
            if [ -f "$text_file" ]; then
                echo "✅ Текст успешно сохранен: $(basename "$text_file")"
            else
                echo "⚠️  Whisper отработал без ошибки, но файл текста не найден: $text_file"
            fi
            echo "📊 Статистика:"
            echo "   - Размер видео: $(du -h "$video_file" | cut -f1)"
            echo "   - Размер аудио: $(du -h "$audio_file" | cut -f1)"
            if [ -f "$text_file" ]; then
                echo "   - Размер текста: $(du -h "$text_file" | cut -f1)"
            fi
            echo "   - Длительность аудио: $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null | cut -d. -f1) сек"
            
            # Перемещаем обработанный видео файл в папку processed
            mkdir -p "$VIDEO_INPUT_DIR/processed"
            mv "$video_file" "$VIDEO_INPUT_DIR/processed/"
            echo "📁 Видео перемещено в папку processed"
        else
            echo "❌ Ошибка при распознавании речи"
        fi
    else
        echo "❌ Ошибка при извлечении аудио"
    fi
    
    echo "────────────────────────────────────────"
    echo ""
}

# Основная часть
echo "🎥 Автоматическая обработка видео файлов"
echo "📁 Папка для видео: $VIDEO_INPUT_DIR"
echo "🎵 Папка для аудио: $AUDIO_OUTPUT_DIR"
echo "📝 Папка для текста: $TEXT_OUTPUT_DIR"
echo ""

# Создаем необходимые папки
mkdir -p "$VIDEO_INPUT_DIR"
mkdir -p "$AUDIO_OUTPUT_DIR" 
mkdir -p "$TEXT_OUTPUT_DIR"

# Проверяем наличие whisper
if [ ! -f "$WHISPER_PATH" ]; then
    echo "❌ Ошибка: whisper-cli не найден по пути: $WHISPER_PATH"
    exit 1
fi

# Проверяем наличие ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ Ошибка: ffmpeg не найден. Установите его: brew install ffmpeg"
    exit 1
fi

# Проверяем наличие модели whisper
if [ ! -f "$WHISPER_MODEL_PATH" ]; then
    echo "❌ Модель whisper не найдена: $WHISPER_MODEL_PATH"
    exit 1
fi

# Отслеживаем новые файлы
echo "👀 Начинаю отслеживание новых видео файлов..."
echo "📂 Поместите видео файлы в папку: $VIDEO_INPUT_DIR"
echo "ℹ️  Чтобы включить VAD: USE_VAD=1 ./video_processor.sh"
echo "ℹ️  Язык распознавания: $WHISPER_LANG (переопределить: WHISPER_LANG=auto)"
echo ""

# Используем fswatch для отслеживания новых файлов (если установлен)
if command -v fswatch &> /dev/null; then
    echo "✅ Использую fswatch для отслеживания файлов"
    fswatch -o -e "processed" "$VIDEO_INPUT_DIR" | while read event; do
        echo "🔄 Обнаружено изменение в папке видео..."
        sleep 2  # Даем время на завершение копирования файла
        
        # Обрабатываем все видео файлы в папке
        for video_file in "$VIDEO_INPUT_DIR"/*.{mp4,avi,mov,mkv,flv,wmv}; do
            if [ -f "$video_file" ]; then
                process_video "$video_file"
            fi
        done
    done
else
    echo "⚠️  fswatch не установлен. Буду проверять папку каждые 5 секунд."
    echo "💡 Установите fswatch для мгновенной обработки: brew install fswatch"
    echo ""
    
    while true; do
        for video_file in "$VIDEO_INPUT_DIR"/*.{mp4,avi,mov,mkv,flv,wmv}; do
            if [ -f "$video_file" ]; then
                process_video "$video_file"
            fi
        done
        sleep 5
    done
fi
