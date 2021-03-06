#pragma once

// global headers
#include <string>

namespace appimage {
    namespace update {
        /**
         * Primary class of AppImageUpdate. Abstracts entire functionality.
         *
         * Update is run asynchronously in a separate thread. The owner of the instance can query the progress.
         */
        class Updater {
        public:
            // Represents current state of the updater
            enum State {
                INITIALIZED,
                RUNNING,
                STOPPING,
                SUCCESS,
                ERROR,
            };

        private:
            // opaque private class
            // without this pattern, the header would require C++11, which is undesirable
            class Private;
            Private* d;

        private:
            // thread runner -- should be called from start() only
            void runUpdate();

        public:
            // throws std::invalid_argument if the file does not exist
            // if overwrite is specified, old file will be overwritten, otherwise it will remain on the system
            // as-is
            explicit Updater(const std::string& pathToAppImage, bool overwrite = false);
            ~Updater();

        public:
            // Start update process. If running/finished already, returns false, otherwise true.
            bool start();

            // Interrupt update process as soon as possible. Throws exception if the update has not been started.
            // Returns false if stop() has been called already.
            bool stop();

            // Returns current state of the updater.
            State state();

            // Convenience function returning true when the update has finished. Uses state() internally.
            // Beware that it will return true in case of errors, too! Combine with either state() or hasError()!
            bool isDone();

            // Convenience function returning whether an error has occured. Uses state() internally.
            // Beware that it will return false even if the update process has not yet begun, or is currently running!
            bool hasError();

            // Sets given parameter to current progress. Returns false in case of failure, i.e., the update process
            // is not running or the version of the AppImage format is not supported, otherwise true.
            bool progress(double& progress);

            // Fetch a status message from the client in use that can be used to display updates
            bool nextStatusMessage(std::string& message);

            // Check whether an update is available
            // Please note that this method is *only* available until the update is started (after calling start(),
            // the method will instantly return false)
            bool checkForChanges(bool& updateAvailable, unsigned int method = 0);

            // Parses AppImage file, and returns a formatted string describing it
            // in case of success, sets description and returns true, false otherwise
            bool describeAppImage(std::string& description);

            // Sets path to the path of the file created by the update and returns true as soon as this value is
            // available (after a successful update at the latest)
            // Returns false in case of errors, or when the path is not available yet
            bool pathToNewFile(std::string& path);

            // Returns the size of the remote file in bytes
            bool remoteFileSize(off_t& fileSize);
        };
    }
}
