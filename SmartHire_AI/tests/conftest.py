"""Shared test setup.

These are pure-logic unit tests for the matching / gap-analysis services. They
should not require the embedding model or a running vector database, so we stub
the heavy optional dependencies when they are not installed in the test
environment. Tests here never call embed_text(), so the stubs are never invoked.
"""
import sys
import types


def _stub_module(name: str, attrs: dict):
    if name in sys.modules:
        return
    try:
        __import__(name)
        return
    except ImportError:
        pass
    module = types.ModuleType(name)
    for key, value in attrs.items():
        setattr(module, key, value)
    sys.modules[name] = module


class _StubSentenceTransformer:
    def __init__(self, *args, **kwargs):
        pass

    def encode(self, *args, **kwargs):
        raise RuntimeError("embedding is not available in unit tests")


_stub_module("sentence_transformers", {"SentenceTransformer": _StubSentenceTransformer})


class _StubMilvusClient:
    def __init__(self, *args, **kwargs):
        pass


_stub_module("pymilvus", {"MilvusClient": _StubMilvusClient})
