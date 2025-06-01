#!/bin/bash

echo "Ligne 1 (stdout)"
echo "Ligne A (stderr)" >&2
echo "Ligne 2 (stdout)"
sleep 1
echo "Ligne B (stderr)" >&2
echo "Ligne 3 (stdout)"
exit 0