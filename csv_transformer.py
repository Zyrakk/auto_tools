#!/usr/bin/env python3
"""
csv_transformer.py - Transformación estructural de CSVs
Autor: Zyrak
"""

import csv
import os
import sys
import logging
from pathlib import Path
from dataclasses import dataclass, field

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

CONFIG = {
    # Rutas (sobreescribibles con variables de entorno)
    "input_dir": os.getenv("CSV_INPUT_DIR", "./input"),
    "output_dir": os.getenv("CSV_OUTPUT_DIR", "./output"),
    
    # Formato CSV de entrada
    "delimiter": "\t",
    "has_headers": True,
    "encoding": "utf-8",
    
    # Columnas del CSV de entrada (en orden)
    "input_columns": ["columna1", "columna2", "columna3", "columna4"],
    
    # Agrupación (None para desactivar)
    "group_by_column": "columna1",
    "sort_before_grouping": True,
    
    # Separación de columnas
    "split_columns": [
        {
            "source": "columna3",
            "separators": [" => ", " "],    # Se aplican en orden
            "chars_to_remove": [],
            "new_columns": ["columna3.1", "columna3.2", "columna3.3"],
            "remove_original": True
        }
    ],
    
    # Renombrado {original: nuevo}
    "rename_columns": {
        "columna2": "renombrado1",
        "columna4": "renombrado2"
    },
    
    # Orden de salida (None para mantener orden original)
    "output_column_order": [
        "columna1", "columna3.1", "columna3.2", 
        "columna3.3", "renombrado1", "renombrado2"
    ],
    
    # Columnas a excluir
    "exclude_columns": [],
    
    # Sufijo archivos de salida
    "output_suffix": "_transformed",
    
    "log_level": "INFO"
}

# ============================================================================
# TRANSFORMADOR
# ============================================================================

@dataclass
class SplitConfig:
    source: str
    separators: list
    new_columns: list
    chars_to_remove: list = field(default_factory=list)
    remove_original: bool = True


class CSVTransformer:
    
    def __init__(self, config: dict):
        self.config = config
        self.logger = self._setup_logging()
    
    def _setup_logging(self) -> logging.Logger:
        logger = logging.getLogger("csv_transformer")
        logger.setLevel(getattr(logging, self.config.get("log_level", "INFO")))
        if not logger.handlers:
            handler = logging.StreamHandler(sys.stdout)
            handler.setFormatter(logging.Formatter("[%(asctime)s] %(levelname)s: %(message)s", "%Y-%m-%d %H:%M:%S"))
            logger.addHandler(handler)
        return logger
    
    def _read_csv(self, filepath: Path) -> tuple[list[str], list[dict]]:
        rows = []
        headers = self.config["input_columns"]
        
        with open(filepath, "r", encoding=self.config["encoding"], newline="") as f:
            reader = csv.reader(f, delimiter=self.config["delimiter"])
            
            if self.config["has_headers"]:
                file_headers = next(reader, None)
                if file_headers:
                    headers = [h.strip() for h in file_headers]
            
            for line in reader:
                if not line or all(c.strip() == "" for c in line):
                    continue
                row = {headers[i] if i < len(headers) else f"col_{i}": v for i, v in enumerate(line)}
                rows.append(row)
        
        return headers, rows
    
    def _write_csv(self, filepath: Path, headers: list[str], rows: list[dict]):
        with open(filepath, "w", encoding=self.config["encoding"], newline="") as f:
            writer = csv.writer(f, delimiter=",")  # Salida siempre en coma estándar
            writer.writerow(headers)
            for row in rows:
                writer.writerow([row.get(h, "") for h in headers])
    
    def _split_value(self, value: str, cfg: SplitConfig) -> list[str]:
        temp = "\x00"
        result = value
        for sep in cfg.separators:
            result = result.replace(sep, temp)
        
        parts = result.split(temp)
        
        cleaned = []
        for part in parts:
            for char in cfg.chars_to_remove:
                part = part.replace(char, "")
            cleaned.append(part.strip())
        
        return cleaned
    
    def _apply_splits(self, headers: list[str], rows: list[dict]) -> tuple[list[str], list[dict]]:
        new_headers = list(headers)
        
        for split_dict in self.config.get("split_columns", []):
            cfg = SplitConfig(**split_dict)
            
            if cfg.source not in new_headers:
                continue
            
            source_idx = new_headers.index(cfg.source)
            
            for row in rows:
                parts = self._split_value(row.get(cfg.source, ""), cfg)
                for i, col in enumerate(cfg.new_columns):
                    row[col] = parts[i] if i < len(parts) else ""
            
            if cfg.remove_original:
                new_headers.remove(cfg.source)
                for row in rows:
                    row.pop(cfg.source, None)
            
            for i, col in enumerate(cfg.new_columns):
                if col not in new_headers:
                    new_headers.insert(source_idx + i, col)
        
        return new_headers, rows
    
    def _apply_renames(self, headers: list[str], rows: list[dict]) -> tuple[list[str], list[dict]]:
        rename_map = self.config.get("rename_columns", {})
        
        new_headers = [rename_map.get(h, h) for h in headers]
        
        for row in rows:
            for old, new in rename_map.items():
                if old in row:
                    row[new] = row.pop(old)
        
        return new_headers, rows
    
    def _apply_grouping(self, headers: list[str], rows: list[dict]) -> list[dict]:
        group_col = self.config.get("group_by_column")
        if not group_col:
            return rows
        
        rename_map = self.config.get("rename_columns", {})
        actual_col = rename_map.get(group_col, group_col)
        
        if actual_col not in headers:
            return rows
        
        if self.config.get("sort_before_grouping", True):
            rows = sorted(rows, key=lambda r: r.get(actual_col, ""))
        
        prev = None
        for row in rows:
            current = row.get(actual_col)
            if current == prev:
                row[actual_col] = ""
            else:
                prev = current
        
        return rows
    
    def _apply_column_order(self, headers: list[str], rows: list[dict]) -> tuple[list[str], list[dict]]:
        output_order = self.config.get("output_column_order")
        exclude = set(self.config.get("exclude_columns", []))
        
        if not output_order:
            return [h for h in headers if h not in exclude], rows
        
        final = [h for h in output_order if h in headers and h not in exclude]
        
        for h in headers:
            if h not in final and h not in exclude:
                final.append(h)
        
        return final, rows
    
    def transform(self, input_path: Path, output_path: Path) -> bool:
        try:
            self.logger.info(f"Procesando: {input_path.name}")
            
            headers, rows = self._read_csv(input_path)
            
            if not rows:
                self.logger.warning(f"Archivo vacío: {input_path.name}")
                return False
            
            headers, rows = self._apply_splits(headers, rows)
            headers, rows = self._apply_renames(headers, rows)
            rows = self._apply_grouping(headers, rows)
            headers, rows = self._apply_column_order(headers, rows)
            
            self._write_csv(output_path, headers, rows)
            self.logger.info(f"Generado: {output_path.name} ({len(rows)} filas)")
            
            return True
            
        except Exception as e:
            self.logger.error(f"Error: {input_path.name} - {e}")
            return False
    
    def process_directory(self) -> dict:
        input_dir = Path(self.config["input_dir"])
        output_dir = Path(self.config["output_dir"])
        suffix = self.config["output_suffix"]
        
        output_dir.mkdir(parents=True, exist_ok=True)
        
        stats = {"processed": 0, "failed": 0}
        
        if not input_dir.exists():
            self.logger.error(f"Directorio no existe: {input_dir}")
            return stats
        
        csv_files = list(input_dir.glob("*.csv"))
        
        if not csv_files:
            self.logger.warning(f"Sin archivos CSV en {input_dir}")
            return stats
        
        self.logger.info(f"Encontrados {len(csv_files)} archivos")
        
        for f in csv_files:
            output_file = output_dir / f"{f.stem}{suffix}.csv"
            if self.transform(f, output_file):
                stats["processed"] += 1
            else:
                stats["failed"] += 1
        
        return stats
    
    def process_single(self, input_path: str, output_path: str = None) -> bool:
        input_file = Path(input_path)
        
        if not input_file.exists():
            self.logger.error(f"No encontrado: {input_path}")
            return False
        
        if output_path:
            output_file = Path(output_path)
        else:
            output_file = input_file.parent / f"{input_file.stem}{self.config['output_suffix']}.csv"
        
        return self.transform(input_file, output_file)


def main():
    transformer = CSVTransformer(CONFIG)
    
    if len(sys.argv) > 1:
        for filepath in sys.argv[1:]:
            transformer.process_single(filepath)
    else:
        stats = transformer.process_directory()
        transformer.logger.info(f"Completado - OK: {stats['processed']}, Fallos: {stats['failed']}")
        if stats["failed"] > 0:
            sys.exit(1)


if __name__ == "__main__":
    main()
