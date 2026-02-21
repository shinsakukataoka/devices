## Important Files
```bash
/config/MRAM_configs/MRAM_*nm_*MB.cfg
/config/MRAM_configs/MRAM_*nm.cell
/config/SRAM_configs/SRAM_*nm_*MB.cfg
/config/SRAM_configs/SRAM_*nm.cell
/results/cache_sweep/<run_id>          # Example: 20251121T235434Z (timestamp-based run ID)
scripts/summarize_cache_sweep.py
run_cache_sweep.sh
run_cache_sweep.sbatch
```

## How to Run
```bash
sbatch run_cache_sweep.sbatch
python3 scripts/summarize_cache_sweep.py <run_id> --csv_name myoutput.csv
# Example:
# python3 scripts/summarize_cache_sweep.py 20251121T235434Z --csv_name myoutput.csv
cat /home/skataoka26/COSC_498/devices/results/cache_sweep/20251121T235434Z/myoutput.csv
```





