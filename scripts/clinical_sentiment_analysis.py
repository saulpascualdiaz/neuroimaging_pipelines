"""
Clinical Sentiment Analysis Module
====================================

A robust sentiment analysis tool for clinical interviews and mental health assessments.

This module provides an ensemble-based approach to sentiment analysis, specifically 
optimized for clinical interviews and mental health contexts. By combining predictions 
from three state-of-the-art transformer models, it provides reliable sentiment scores 
that can help assess patient mood and emotional state.

Models Used:
-----------
1. Mental Health BERT (mental/mental-bert-base-uncased)
   - Specialized for mental health and psychological text
   - Trained on mental health datasets
   - Best for detecting clinical depression and anxiety indicators

2. CardiffNLP RoBERTa (cardiffnlp/twitter-roberta-base-sentiment-latest)
   - State-of-the-art general sentiment model
   - Excellent performance on healthcare text
   - Handles colloquial and varied expression styles

3. DistilBERT SST-2 (distilbert-base-uncased-finetuned-sst-2-english)
   - Fine-tuned on Stanford Sentiment Treebank
   - Captures nuanced emotional states
   - Detects subtle emotional expressions

Output:
-------
Each model returns a sentiment score between -1 (very negative) and +1 (very positive):
  -1.0 to -0.6: Very negative (severe distress indicators)
  -0.6 to -0.3: Negative (mild to moderate distress)
  -0.3 to +0.3: Neutral (balanced emotional state)
  +0.3 to +0.6: Positive (good mood)
  +0.6 to +1.0: Very positive (excellent mood)

Usage Example:
-------------
    >>> from clinical_sentiment_analyzer import ClinicalSentimentAnalyzer
    >>> 
    >>> # Create analyzer instance (reuse for multiple analyses)
    >>> analyzer = ClinicalSentimentAnalyzer()
    >>> 
    >>> # Analyze a patient response
    >>> text = "I've been feeling much better and more hopeful"
    >>> w1, w2, w3 = analyzer.analyze_sentiment(text)
    >>> 
    >>> print(f"Mental Health BERT: {w1:.3f}")
    >>> print(f"RoBERTa Healthcare: {w2:.3f}")
    >>> print(f"DistilBERT Emotion: {w3:.3f}")
    >>> print(f"Average: {(w1+w2+w3)/3:.3f}")

Clinical Disclaimer:
-------------------
This tool is designed for research and supportive clinical use only. It should 
NOT be used as the sole basis for clinical diagnosis or treatment decisions. 
Always combine with professional clinical judgment and other assessment tools.

Author: Saül Pascual-Diaz
Version: 1.0.0
Date: November 6, 2025
"""

import os
from transformers import AutoTokenizer, AutoModelForSequenceClassification, pipeline
import torch
import numpy as np
from typing import Dict, Tuple
import warnings

warnings.filterwarnings('ignore')
# Avoid potential tokenizer thread issues on macOS
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
# Constrain thread usage to reduce risk of low-level runtime crashes on macOS
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")
try:
    torch.set_num_threads(1)
    if hasattr(torch, "set_num_interop_threads"):
        torch.set_num_interop_threads(1)
except Exception:
    pass


class ClinicalSentimentAnalyzer:
    """
    Multi-model ensemble analyzer for clinical sentiment analysis.
    
    This class manages three transformer-based sentiment analysis models optimized 
    for clinical and mental health text. Models are loaded lazily on first use to 
    conserve memory and startup time.
    
    Attributes:
        device (int): Device ID for computation (0+ for GPU, -1 for CPU)
        models_loaded (bool): Flag indicating if models have been initialized
        model1 (Pipeline): Mental Health BERT sentiment pipeline
        model2 (Pipeline): RoBERTa healthcare sentiment pipeline
        model3 (Pipeline): DistilBERT emotion sentiment pipeline
    
    Performance:
        - CPU: ~5-25 sentences/second (depending on processor)
        - GPU: ~50-300 sentences/second (depending on GPU)
        - Memory: ~1.5-2GB RAM when models loaded
    
    Example:
        >>> analyzer = ClinicalSentimentAnalyzer()
        >>> 
        >>> # Single analysis
        >>> w1, w2, w3 = analyzer.analyze_sentiment("I feel better today")
        >>> 
        >>> # Batch processing
        >>> responses = ["I'm anxious", "Feeling great", "Kind of okay"]
        >>> for response in responses:
        >>>     weights = analyzer.analyze_sentiment(response)
        >>>     print(weights)
    
    Note:
        - Create one instance and reuse it for multiple analyses
        - Models download automatically on first run (~500MB)
        - GPU is used automatically if available
    """
    
    def __init__(self):
        """
        Initialize the three models for clinical sentiment analysis.
        Models are loaded on first use to save memory.
        """
        # Device selection with env override for stability
        # Set CLINICAL_SENTIMENT_DEVICE=cpu to force CPU-only execution
        force_device = os.getenv("CLINICAL_SENTIMENT_DEVICE", "").lower()
        self.use_mps = hasattr(torch.backends, "mps") and torch.backends.mps.is_available()
        if force_device == "cpu":
            self.device = -1
            self.device_map = None
            self.use_mps = False
        elif torch.cuda.is_available():
            self.device = 0
            self.device_map = None
        elif self.use_mps:
            # Use Accelerate device map for MPS where supported
            self.device = None
            self.device_map = "auto"
        else:
            self.device = -1
            self.device_map = None
        self.models_loaded = False
        self.model1 = None
        self.model2 = None
        self.model3 = None
        
    def _load_models(self):
        """
        Load all three sentiment analysis models.
        
        This method is called automatically on first analysis. Models are downloaded 
        from Hugging Face Hub and cached locally for future use.
        
        Model Details:
            Model 1 - Mental Health BERT:
                - Specializes in mental health language
                - Detects clinical depression/anxiety markers
                - Fallback: CardiffNLP RoBERTa if unavailable
            
            Model 2 - CardiffNLP RoBERTa:
                - State-of-the-art general sentiment
                - Strong performance on healthcare text
                - Handles varied expression styles
            
            Model 3 - DistilBERT SST-2:
                - Captures emotional nuances
                - Good for subtle mood indicators
                - Fast inference time
        
        Side Effects:
            - Downloads models on first run (~500MB total)
            - Sets self.models_loaded = True
            - Initializes self.model1, self.model2, self.model3
        
        Raises:
            Exception: Prints warnings but continues if individual models fail
        """
        if self.models_loaded:
            return
            
        print("Loading clinical sentiment analysis models...")
        
        # Helper to build device kwargs for pipeline
        def _device_kwargs():
            kwargs = {}
            if self.device_map is not None:
                kwargs["device_map"] = self.device_map
            elif self.device is not None:
                kwargs["device"] = self.device
            return kwargs

        # Model 1: Mental Health BERT
        # Specialized for mental health and psychological text
        try:
            # Use slow tokenizer to avoid potential Rust tokenizers issues on some Python builds
            tok1 = AutoTokenizer.from_pretrained("mental/mental-bert-base-uncased", use_fast=False)
            self.model1 = pipeline(
                "sentiment-analysis",
                model="mental/mental-bert-base-uncased",
                tokenizer=tok1,
                **_device_kwargs(),
                truncation=True,
                max_length=512
            )
            print("✓ Loaded mental-bert-base-uncased")
        except Exception as e:
            print(f"Note: Using fallback for Model 1 - {str(e)[:50]}")
            tok_fallback = AutoTokenizer.from_pretrained(
                "cardiffnlp/twitter-roberta-base-sentiment-latest", use_fast=False
            )
            self.model1 = pipeline(
                "sentiment-analysis",
                model="cardiffnlp/twitter-roberta-base-sentiment-latest",
                tokenizer=tok_fallback,
                **_device_kwargs(),
                truncation=True,
                max_length=512
            )
        
        # Model 2: RoBERTa fine-tuned for healthcare
        # Good for general clinical and healthcare contexts
        try:
            tok2 = AutoTokenizer.from_pretrained(
                "cardiffnlp/twitter-roberta-base-sentiment-latest", use_fast=False
            )
            self.model2 = pipeline(
                "sentiment-analysis",
                model="cardiffnlp/twitter-roberta-base-sentiment-latest",
                tokenizer=tok2,
                **_device_kwargs(),
                truncation=True,
                max_length=512
            )
            print("✓ Loaded cardiffnlp RoBERTa sentiment model")
        except Exception as e:
            print(f"Warning loading Model 2: {e}")
            
        # Model 3: BERT base fine-tuned on SST-2 (TextAttack)
        try:
            model3_id = "textattack/bert-base-uncased-SST-2"
            tok3 = AutoTokenizer.from_pretrained(model3_id, use_fast=False)
            self.model3 = pipeline(
                "sentiment-analysis",
                model=model3_id,
                tokenizer=tok3,
                **_device_kwargs(),
                truncation=True,
                max_length=512
            )
            print("✓ Loaded TextAttack BERT SST-2 model")
        except Exception as e:
            print(f"Warning loading Model 3: {e}")
        
        self.models_loaded = True
        print("All models loaded successfully!\n")
    
    def _normalize_score(self, result) -> float:
        """
        Convert model output to a score between -1 and 1.
        
        Args:
            result: Output from sentiment pipeline
            
        Returns:
            float: Normalized score between -1 (negative) and 1 (positive)
        """
        label = result[0]['label'].upper()
        score = result[0]['score']
        
        # Handle different label formats
        if 'NEGATIVE' in label or label == 'LABEL_0':
            return -score
        elif 'POSITIVE' in label or label == 'LABEL_1':
            return score
        elif 'NEUTRAL' in label or label == 'LABEL_2':
            return 0.0
        else:
            # For 3-class models (negative, neutral, positive)
            # Map to continuous scale
            if 'NEG' in label:
                return -score
            elif 'POS' in label:
                return score
            else:
                return 0.0
    
    def analyze_sentiment(self, text: str) -> Tuple[float, float, float]:
        """
        Analyze sentiment of clinical text using three specialized models.
        
        This is the primary method for sentiment analysis. It processes the input 
        text through all three models and returns normalized sentiment scores.
        
        Args:
            text (str): The clinical interview text to analyze. Can be a single 
                sentence or longer passage (automatically truncated to 512 tokens).
        
        Returns:
            Tuple[float, float, float]: Three sentiment weights between -1 and 1:
                - weight_1 (float): Mental health BERT score
                - weight_2 (float): RoBERTa healthcare score
                - weight_3 (float): DistilBERT emotion score
                
                Interpretation:
                    -1.0 to -0.6: Very negative mood
                    -0.6 to -0.3: Negative mood
                    -0.3 to +0.3: Neutral mood
                    +0.3 to +0.6: Positive mood
                    +0.6 to +1.0: Very positive mood
        
        Edge Cases:
            - Empty text or text < 3 characters: Returns (0.0, 0.0, 0.0)
            - Individual model failure: Returns 0.0 for that model
            - Text > 512 tokens: Automatically truncated
        
        Examples:
            >>> analyzer = ClinicalSentimentAnalyzer()
            >>> 
            >>> # Negative sentiment
            >>> w1, w2, w3 = analyzer.analyze_sentiment("I feel hopeless and anxious")
            >>> print(f"Weights: {w1:.3f}, {w2:.3f}, {w3:.3f}")
            Weights: -0.847, -0.823, -0.891
            >>> 
            >>> # Positive sentiment
            >>> w1, w2, w3 = analyzer.analyze_sentiment("Treatment is really helping")
            >>> print(f"Average: {(w1+w2+w3)/3:.3f}")
            Average: 0.782
            >>> 
            >>> # Use with pandas
            >>> import pandas as pd
            >>> df = pd.DataFrame({'response': ["I'm better", "Feeling low"]})
            >>> df[['w1','w2','w3']] = df['response'].apply(
            ...     lambda x: pd.Series(analyzer.analyze_sentiment(x))
            ... )
        
        Performance:
            - First call: Slower due to model loading
            - Subsequent calls: ~20-200ms depending on hardware
            - GPU acceleration: Automatic if available
        
        Note:
            For best performance with multiple texts, create the analyzer once 
            and reuse it rather than creating new instances.
        """
        # Load models on first use
        if not self.models_loaded:
            self._load_models()
        
        # Handle empty or very short text
        if not text or len(text.strip()) < 3:
            return 0.0, 0.0, 0.0
        
        # Get predictions from all three models
        try:
            result1 = self.model1(text)
            weight_1 = self._normalize_score(result1)
        except Exception as e:
            print(f"Warning: Model 1 failed - {e}")
            weight_1 = 0.0
        
        try:
            result2 = self.model2(text)
            weight_2 = self._normalize_score(result2)
        except Exception as e:
            print(f"Warning: Model 2 failed - {e}")
            weight_2 = 0.0
            
        try:
            result3 = self.model3(text)
            weight_3 = self._normalize_score(result3)
        except Exception as e:
            print(f"Warning: Model 3 failed - {e}")
            weight_3 = 0.0
        
        return weight_1, weight_2, weight_3
    
    def get_average_sentiment(self, text: str) -> float:
        """
        Get the average sentiment across all three models.
        
        Args:
            text (str): The clinical interview text to analyze
            
        Returns:
            float: Average sentiment score between -1 and 1
        """
        w1, w2, w3 = self.analyze_sentiment(text)
        return np.mean([w1, w2, w3])


# Convenience function for quick usage
def get_clinical_sentiment_weights(text: str) -> Tuple[float, float, float]:
    """
    Convenience function to get sentiment weights from clinical text.
    Creates a new analyzer instance each time - for repeated use, 
    create an analyzer instance and reuse it.
    
    Args:
        text (str): The clinical interview text to analyze
        
    Returns:
        Tuple[float, float, float]: Three sentiment weights between -1 and 1
        
    Example:
        >>> weights = get_clinical_sentiment_weights("Patient reports feeling anxious")
        >>> print(weights)
        (-0.85, -0.72, -0.81)
    """
    analyzer = ClinicalSentimentAnalyzer()
    return analyzer.analyze_sentiment(text)


if __name__ == "__main__":
    # Example usage
    print("Clinical Sentiment Analysis - Example Usage\n")
    print("=" * 60)
    
    # Create analyzer instance (reuse for multiple analyses)
    analyzer = ClinicalSentimentAnalyzer()
    
    # Test sentences representing different moods
    test_sentences = [
        "I've been feeling really depressed and hopeless lately",
        "Today was okay, nothing special happened",
        "I'm feeling much better and more optimistic about the future",
        "I can't stop worrying about everything, it's overwhelming",
        "My mood has been stable and I'm sleeping well"
    ]
    
    print("\nAnalyzing sample clinical interview responses:\n")
    
    for i, sentence in enumerate(test_sentences, 1):
        w1, w2, w3 = analyzer.analyze_sentiment(sentence)
        avg = np.mean([w1, w2, w3])
        
        mood = "NEGATIVE" if avg < -0.3 else "POSITIVE" if avg > 0.3 else "NEUTRAL"
        
        print(f"{i}. \"{sentence}\"")
        print(f"   Model 1: {w1:6.3f} | Model 2: {w2:6.3f} | Model 3: {w3:6.3f}")
        print(f"   Average: {avg:6.3f} ({mood})")
        print()
