#!/usr/bin/env python3
"""
Context Engineering Utilities
Machine learning system for continuous improvement of the agentic workflow
"""

import os
import sys
import yaml
import json
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional
import hashlib

class ContextEngineeringUtils:
    """Utilities for managing the ML learning system"""
    
    def __init__(self, base_path: str = "."):
        self.base_path = Path(base_path)
        self.kb_path = self.base_path / ".agent" / "orchestration" / "knowledge_base"
        self.kb_path.mkdir(parents=True, exist_ok=True)
        
        # Knowledge base files
        self.failure_patterns_file = self.kb_path / "failure_patterns.yaml"
        self.success_metrics_file = self.kb_path / "success_metrics.yaml"
        self.template_versions_file = self.kb_path / "template_versions.yaml"
        self.library_gotchas_file = self.kb_path / "library_gotchas.yaml"
    
    def init(self):
        """Initialize the knowledge base with default structures"""
        print("🧠 Initializing knowledge base...")
        
        # Initialize failure patterns
        if not self.failure_patterns_file.exists():
            default_patterns = {
                'failure_patterns': [
                    {
                        'id': 'async_await_mixing',
                        'description': 'Mixing async and sync code without proper await',
                        'frequency': 'high',
                        'detection_signs': [
                            'Promise returned without await',
                            'async function called synchronously'
                        ],
                        'prevention': [
                            'Always use await with async functions',
                            'Mark calling function as async if needed',
                            'Use .then() only for fire-and-forget'
                        ],
                        'related_libraries': ['react', 'react-native', 'node.js'],
                        'example_error': 'TypeError: Cannot read property of undefined',
                        'fix_template': 'Add await before the async call: await functionName()'
                    }
                ]
            }
            self._save_yaml(self.failure_patterns_file, default_patterns)
            print(f"  ✓ Created {self.failure_patterns_file}")
        
        # Initialize success metrics
        if not self.success_metrics_file.exists():
            default_metrics = {
                'success_metrics': []
            }
            self._save_yaml(self.success_metrics_file, default_metrics)
            print(f"  ✓ Created {self.success_metrics_file}")
        
        # Initialize template versions
        if not self.template_versions_file.exists():
            default_versions = {
                'template_versions': [
                    {
                        'version': 'v1.0',
                        'date': datetime.now().isoformat(),
                        'improvements': ['Initial template creation'],
                        'success_rate_improvement': 0
                    }
                ]
            }
            self._save_yaml(self.template_versions_file, default_versions)
            print(f"  ✓ Created {self.template_versions_file}")
        
        # Initialize library gotchas
        if not self.library_gotchas_file.exists():
            default_gotchas = {
                'library_gotchas': []
            }
            self._save_yaml(self.library_gotchas_file, default_gotchas)
            print(f"  ✓ Created {self.library_gotchas_file}")
        
        print("✅ Knowledge base initialized successfully!")
    
    def add_failure_pattern(self, pattern: Dict[str, Any]) -> None:
        """Add a new failure pattern to the knowledge base"""
        data = self._load_yaml(self.failure_patterns_file)
        
        # Generate ID if not provided
        if 'id' not in pattern:
            pattern['id'] = self._generate_id(pattern['description'])
        
        # Add timestamp
        pattern['added_date'] = datetime.now().isoformat()
        pattern['frequency'] = pattern.get('frequency', 'low')
        
        data['failure_patterns'].append(pattern)
        self._save_yaml(self.failure_patterns_file, data)
        print(f"✓ Added failure pattern: {pattern['id']}")
    
    def get_failure_patterns(self, libraries: Optional[List[str]] = None) -> List[Dict]:
        """Get failure patterns, optionally filtered by libraries"""
        data = self._load_yaml(self.failure_patterns_file)
        patterns = data.get('failure_patterns', [])
        
        if libraries:
            filtered = []
            for pattern in patterns:
                related_libs = pattern.get('related_libraries', [])
                if any(lib.lower() in [r.lower() for r in related_libs] for lib in libraries):
                    filtered.append(pattern)
            return filtered
        
        return patterns
    
    def add_success_metric(self, metric: Dict[str, Any]) -> None:
        """Record a successful implementation metric"""
        data = self._load_yaml(self.success_metrics_file)
        
        metric['timestamp'] = datetime.now().isoformat()
        metric['id'] = self._generate_id(f"{metric.get('feature_type', 'unknown')}_{metric['timestamp']}")
        
        data['success_metrics'].append(metric)
        self._save_yaml(self.success_metrics_file, data)
        print(f"✓ Recorded success metric: {metric.get('feature_type', 'unknown')}")
    
    def get_relevant_success_metrics(self, feature_types: List[str], limit: int = 10) -> Dict:
        """Get success metrics for similar feature types"""
        data = self._load_yaml(self.success_metrics_file)
        metrics = data.get('success_metrics', [])
        
        # Filter by feature type
        relevant = [m for m in metrics if m.get('feature_type') in feature_types]
        
        # Sort by timestamp (most recent first)
        relevant.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
        
        # Limit results
        relevant = relevant[:limit]
        
        # Calculate averages
        if not relevant:
            return {
                'count': 0,
                'avg_implementation_time': None,
                'avg_success_rate': None,
                'metrics': []
            }
        
        avg_time = sum(m.get('implementation_time_minutes', 0) for m in relevant) / len(relevant)
        avg_success = sum(m.get('success_rate', 0) for m in relevant) / len(relevant)
        
        return {
            'count': len(relevant),
            'avg_implementation_time': round(avg_time, 2),
            'avg_success_rate': round(avg_success, 2),
            'metrics': relevant
        }
    
    def analyze_context_effectiveness(self, prp_path: str) -> Dict[str, float]:
        """Analyze which context elements were most effective"""
        # This would analyze the PRP and its outcome
        # For now, return placeholder scores
        return {
            'documentation_urls': 85.0,
            'examples': 90.0,
            'tech_stack_specificity': 80.0,
            'edge_case_coverage': 75.0
        }
    
    def update_template_version(self, improvements: List[str], success_rate_change: float = 0) -> None:
        """Record a new template version with improvements"""
        data = self._load_yaml(self.template_versions_file)
        
        current_version = data['template_versions'][-1]['version']
        major, minor = current_version.replace('v', '').split('.')
        new_version = f"v{major}.{int(minor) + 1}"
        
        new_entry = {
            'version': new_version,
            'date': datetime.now().isoformat(),
            'improvements': improvements,
            'success_rate_improvement': success_rate_change
        }
        
        data['template_versions'].append(new_entry)
        self._save_yaml(self.template_versions_file, data)
        print(f"✓ Updated template to {new_version}")
    
    def add_library_gotcha(self, gotcha: Dict[str, Any]) -> None:
        """Add a library-specific gotcha"""
        data = self._load_yaml(self.library_gotchas_file)
        
        gotcha['added_date'] = datetime.now().isoformat()
        gotcha['id'] = self._generate_id(f"{gotcha.get('library', 'unknown')}_{gotcha.get('issue', '')}")
        
        data['library_gotchas'].append(gotcha)
        self._save_yaml(self.library_gotchas_file, data)
        print(f"✓ Added gotcha for {gotcha.get('library', 'unknown')}")
    
    def get_library_gotchas(self, library: str) -> List[Dict]:
        """Get gotchas for a specific library"""
        data = self._load_yaml(self.library_gotchas_file)
        gotchas = data.get('library_gotchas', [])
        
        return [g for g in gotchas if g.get('library', '').lower() == library.lower()]
    
    def generate_report(self, period_days: int = 30) -> Dict:
        """Generate analytics report"""
        # Load all data
        metrics = self._load_yaml(self.success_metrics_file).get('success_metrics', [])
        patterns = self._load_yaml(self.failure_patterns_file).get('failure_patterns', [])
        
        # Filter by time period
        cutoff = datetime.now().timestamp() - (period_days * 86400)
        recent_metrics = [
            m for m in metrics 
            if datetime.fromisoformat(m.get('timestamp', '2000-01-01')).timestamp() > cutoff
        ]
        
        report = {
            'period_days': period_days,
            'total_implementations': len(recent_metrics),
            'avg_implementation_time': self._calculate_avg(recent_metrics, 'implementation_time_minutes'),
            'avg_success_rate': self._calculate_avg(recent_metrics, 'success_rate'),
            'most_common_patterns': self._get_top_patterns(patterns, limit=5),
            'generated_at': datetime.now().isoformat()
        }
        
        return report
    
    # Helper methods
    
    def _load_yaml(self, file_path: Path) -> Dict:
        """Load YAML file"""
        if not file_path.exists():
            return {}
        
        with open(file_path, 'r') as f:
            return yaml.safe_load(f) or {}
    
    def _save_yaml(self, file_path: Path, data: Dict) -> None:
        """Save YAML file"""
        with open(file_path, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False)
    
    def _generate_id(self, text: str) -> str:
        """Generate a unique ID from text"""
        return hashlib.md5(text.encode()).hexdigest()[:12]
    
    def _calculate_avg(self, items: List[Dict], key: str) -> Optional[float]:
        """Calculate average of a key across items"""
        values = [item.get(key, 0) for item in items if key in item]
        return round(sum(values) / len(values), 2) if values else None
    
    def _get_top_patterns(self, patterns: List[Dict], limit: int) -> List[Dict]:
        """Get most frequent patterns"""
        frequency_map = {'high': 3, 'medium': 2, 'low': 1}
        sorted_patterns = sorted(
            patterns,
            key=lambda x: frequency_map.get(x.get('frequency', 'low'), 0),
            reverse=True
        )
        return sorted_patterns[:limit]


# CLI Interface
if __name__ == "__main__":
    utils = ContextEngineeringUtils()
    
    if len(sys.argv) < 2:
        print("Usage: python context_engineering_utils.py <command> [args]")
        print("\nCommands:")
        print("  init                           - Initialize knowledge base")
        print("  add-pattern <file>             - Add failure pattern from JSON file")
        print("  add-metric <file>              - Add success metric from JSON file")
        print("  get-patterns [library]         - Get failure patterns")
        print("  get-metrics <feature_type>     - Get success metrics")
        print("  generate-report [days]         - Generate analytics report")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "init":
        utils.init()
    
    elif command == "add-pattern":
        if len(sys.argv) < 3:
            print("Error: Provide JSON file path")
            sys.exit(1)
        
        with open(sys.argv[2], 'r') as f:
            pattern = json.load(f)
        utils.add_failure_pattern(pattern)
    
    elif command == "add-metric":
        if len(sys.argv) < 3:
            print("Error: Provide JSON file path")
            sys.exit(1)
        
        with open(sys.argv[2], 'r') as f:
            metric = json.load(f)
        utils.add_success_metric(metric)
    
    elif command == "get-patterns":
        library = sys.argv[2] if len(sys.argv) > 2 else None
        patterns = utils.get_failure_patterns([library] if library else None)
        print(yaml.dump({'patterns': patterns}, default_flow_style=False))
    
    elif command == "get-metrics":
        if len(sys.argv) < 3:
            print("Error: Provide feature type")
            sys.exit(1)
        
        feature_type = sys.argv[2]
        metrics = utils.get_relevant_success_metrics([feature_type])
        print(json.dumps(metrics, indent=2))
    
    elif command == "generate-report":
        days = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        report = utils.generate_report(days)
        print(json.dumps(report, indent=2))
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
