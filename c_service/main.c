#include <microhttpd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <signal.h>

#define PORT 5000

static enum MHD_Result handle_request(void *cls,
                                      struct MHD_Connection *conn,
                                      const char *url,
                                      const char *method,
                                      const char *version,
                                      const char *upload_data,
                                      size_t *upload_data_size,
                                      void **con_cls)
{
    const char *page;
    if (strcmp(url, "/health") == 0)
    {
        page = "OK";
    }
    else
    {
        page = "Hello from C Service (Low-level tasks)";
    }

    // Create response
    struct MHD_Response *response = MHD_create_response_from_buffer(strlen(page),
                                                                    (void *)page,
                                                                    MHD_RESPMEM_PERSISTENT);
    if (!response)
        return MHD_NO; // Return MHD_NO on error

    // Queue the response
    enum MHD_Result ret = MHD_queue_response(conn, MHD_HTTP_OK, response);
    MHD_destroy_response(response);

    return ret; // MHD_YES or MHD_NO
}

// Rename your global "daemon" variable to something else, e.g., http_daemon
static struct MHD_Daemon *http_daemon;

void stop_server(int sig)
{
    if (http_daemon)
    {
        printf("Stopping C Service...\n");
        MHD_stop_daemon(http_daemon);
        exit(0);
    }
}

int main()
{
    printf("C Service => port %d\n", PORT);

    // Start the MHD daemon
    http_daemon = MHD_start_daemon(MHD_USE_THREAD_PER_CONNECTION,
                                   PORT,
                                   NULL, NULL,
                                   &handle_request, NULL,
                                   MHD_OPTION_END);
    if (!http_daemon)
    {
        fprintf(stderr, "Failed to start microhttpd.\n");
        return 1;
    }

    // Handle signals (Ctrl+C, etc.)
    signal(SIGINT, stop_server);
    signal(SIGTERM, stop_server);

    // Block forever
    pause();

    return 0;
}
