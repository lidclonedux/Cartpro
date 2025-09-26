#!/bin/bash
echo "Capturando logs em tempo real..."
flutter logs --verbose 2>&1 | tee flutter_realtime.log
