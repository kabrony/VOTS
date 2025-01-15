#!/usr/bin/env bash

LOGFILE="dashboard_check.log"
echo "Dashboard check started at \$(date)" > "\$LOGFILE"

echo "[1/2] Running 'npm run lint'..." | tee -a "\$LOGFILE"
npm run lint >> "\$LOGFILE" 2>&1
if [ \$? -ne 0 ]; then
  echo "Lint errors found (see \$LOGFILE)."
else
  echo "Lint passed." | tee -a "\$LOGFILE"
fi

echo "[2/2] Running 'npm run build'..." | tee -a "\$LOGFILE"
npm run build >> "\$LOGFILE" 2>&1
if [ \$? -ne 0 ]; then
  echo "Build errors found (see \$LOGFILE)."
else
  echo "Build passed." | tee -a "\$LOGFILE"
fi

echo "Dashboard check completed at \$(date)" | tee -a "\$LOGFILE"
