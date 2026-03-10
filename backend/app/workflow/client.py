"""Azure OpenAI chat client factory for Microsoft Agent Framework.

Provides a centralized factory function to create AzureOpenAIChatClient
instances configured from application settings.  Authentication is
handled exclusively via Entra ID (``DefaultAzureCredential``).
"""
from __future__ import annotations

import logging
from functools import lru_cache

from agent_framework.azure import AzureOpenAIChatClient

from app.core.config import get_azure_credential, get_settings

logger = logging.getLogger(__name__)


def build_chat_client() -> AzureOpenAIChatClient:
    """Build and return an AzureOpenAIChatClient instance.

    Uses ``DefaultAzureCredential`` for Entra ID authentication.
    In Azure Container Apps this resolves to the user-assigned managed
    identity; locally it falls back to ``az login`` credentials.

    Returns:
        AzureOpenAIChatClient: Configured chat client for Azure OpenAI.
    """
    settings = get_settings()

    endpoint = settings.azure_openai_endpoint
    deployment = settings.azure_openai_deployment_name or "gpt-4o"

    logger.info("✅ Building Azure OpenAI chat client (Entra ID auth)")
    logger.info("   Endpoint: %s", endpoint or "Not set")
    logger.info("   Deployment: %s", deployment)

    return AzureOpenAIChatClient(
        endpoint=endpoint,
        deployment_name=deployment,
        credential=get_azure_credential(),
    )


@lru_cache(maxsize=1)
def get_chat_client() -> AzureOpenAIChatClient:
    """Get a cached AzureOpenAIChatClient instance (singleton).

    Returns:
        AzureOpenAIChatClient: Shared chat client instance.
    """
    return build_chat_client()
