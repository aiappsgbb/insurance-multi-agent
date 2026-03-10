"""Centralised application settings using Pydantic [v2].

All environment variables are optional so the app can still start for local
mock/testing. Access via `get_settings()` for a cached singleton.

Azure OpenAI authentication uses Entra ID (``DefaultAzureCredential``)
exclusively.  Set ``AZURE_CLIENT_ID`` when running under a user-assigned
managed identity (e.g. Azure Container Apps).  For local development,
``az login`` is sufficient.
"""
from __future__ import annotations

import functools
from typing import Any, Callable, Dict

from azure.identity import DefaultAzureCredential

try:
    from pydantic_settings import BaseSettings
    from pydantic import Field
except ImportError:
    # Fallback for older pydantic versions
    from pydantic import BaseSettings, Field


class Settings(BaseSettings):  # noqa: D101
    # Azure OpenAI
    azure_openai_endpoint: str | None = Field(
        default=None, alias="AZURE_OPENAI_ENDPOINT")
    azure_openai_deployment_name: str | None = Field(
        default="gpt-4o", alias="AZURE_OPENAI_DEPLOYMENT_NAME")
    azure_openai_embedding_model: str | None = Field(
        default="text-embedding-ada-002", alias="AZURE_OPENAI_EMBEDDING_MODEL")

    # Entra ID – set AZURE_CLIENT_ID for user-assigned managed identity
    azure_client_id: str | None = Field(
        default=None, alias="AZURE_CLIENT_ID")

    # FastAPI
    app_name: str = "Insurance Multi-Agent Backend"
    api_v1_prefix: str = "/api/v1"

    model_config = {
        "extra": "ignore",
        "env_file": ".env",
        "env_file_encoding": "utf-8",
    }

    def dict_safe(self) -> Dict[str, Any]:  # noqa: D401
        """Serialise settings to a dict (no secrets to exclude)."""
        return self.model_dump()


@functools.lru_cache(maxsize=1)
def get_settings() -> Settings:  # noqa: D401
    """Return a cached Settings instance (singleton)."""
    return Settings()


@functools.lru_cache(maxsize=1)
def get_azure_credential() -> DefaultAzureCredential:
    """Return a cached ``DefaultAzureCredential``.

    When ``AZURE_CLIENT_ID`` is set (user-assigned managed identity in
    Container Apps), it is forwarded so DAC picks the correct identity.
    Locally, ``az login`` credentials are used automatically.
    """
    settings = get_settings()
    kwargs: Dict[str, Any] = {}
    if settings.azure_client_id:
        kwargs["managed_identity_client_id"] = settings.azure_client_id
    return DefaultAzureCredential(**kwargs)


_COGNITIVE_SERVICES_SCOPE = "https://cognitiveservices.azure.com/.default"


@functools.lru_cache(maxsize=1)
def get_token_provider() -> Callable[[], str]:
    """Return a bearer-token provider for Azure OpenAI.

    Compatible with both the ``openai`` SDK (``azure_ad_token_provider``)
    and LangChain's ``AzureOpenAIEmbeddings``.
    """
    from azure.identity import get_bearer_token_provider

    return get_bearer_token_provider(
        get_azure_credential(), _COGNITIVE_SERVICES_SCOPE,
    )
