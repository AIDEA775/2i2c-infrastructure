from pathlib import Path
import os
import pytest
import backoff
from jhub_client.execute import execute_notebook, JupyterHubAPI


@pytest.fixture
def notebook_dir(hub_type):
    return Path(__file__).parent / 'test-notebooks' / hub_type

def failure_handler(details):
    print(f"Hub check health validation failed, hub not healthy.")

def success_handler(details):
    print(f"Notebook execution finished successfully.")



# Try 2 times before declaring it a failure
@backoff.on_exception(
    backoff.expo,
    (ValueError,
    TimeoutError),
    on_success=success_handler,
    on_giveup=failure_handler,
    max_tries=1
)
async def check_hub_health(hub_url, test_notebook_path, service_api_token):
    """
    After each hub gets deployed, validate that it 'works'.

    Automatically create a temporary user, start their server and run a test notebook, making
    sure it runs to completion. Stop and delete the test server at the end. Try this steps twice
    before declaring it a failure. If any of these steps fails, immediately halt further
    deployments and error out.
    """

    username='deployment-service-check'

    # Export the hub health check service as an env var so that jhub_client can read it.
    orig_service_token = os.environ.get('JUPYTERHUB_API_TOKEN', None)

    try:
        os.environ['JUPYTERHUB_API_TOKEN'] = service_api_token

        # Cleanup: if the server takes more than 90s to start, then because it's in a `spawn pending` state,
        # it cannot be deleted. So we delete it in the next iteration, before starting a new one,
        # so that we don't have more than one running.
        hub = JupyterHubAPI(hub_url)
        async with hub:
            user = await hub.get_user(username)
            if user:
                if user['server'] and not user['pending']:
                    await hub.delete_server(username)

                # If we don't delete the user too, than we won't be able to start a kernel for it.
                # This is because we would have lost its api token from the previous run.
                await hub.delete_user(username)

        # Create a new user, start a server and execute a notebook
        await execute_notebook(
            hub_url,
            test_notebook_path,
            username=username,
            server_creation_timeout=360,
            kernel_execution_timeout=360, # This doesn't do anything yet
            create_user=True,
            delete_user=False, # To be able to delete its server in case of failure
            stop_server=True, # If the health check succeeds, this will delete the server
            validate=True
        )
    finally:
        if orig_service_token:
            os.environ['JUPYTERHUB_API_TOKEN'] = orig_service_token


@pytest.mark.asyncio
async def test_hub_healthy(hub_url, api_token, notebook_dir):
    try:
        print(f"Starting hub {hub_url} health validation...")
        for root, directories, files in os.walk(notebook_dir, topdown=False):
            for name in files:
                print(f"Running {name} test notebook...")
                test_notebook_path = os.path.join(root, name)
                await check_hub_health(hub_url, test_notebook_path, api_token)
        print(f"Hub {hub_url} is healthy!")
    except Exception as e:
        print(f"Hub {hub_url} not healthy! Stopping further deployments. Exception was {e}.")
        raise(e)
