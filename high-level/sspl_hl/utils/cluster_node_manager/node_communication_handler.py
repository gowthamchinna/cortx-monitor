# Copyright (c) 2020 Seagate Technology LLC and/or its Affiliates
#
# This program is free software: you can redistribute it and/or modify it under the
# terms of the GNU Affero General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>. For any questions
# about this software or licensing, please email opensource@seagate.com or
# cortx-questions@seagate.com.

"""
Contains Node and NodeCommunicationHandler implementation
"""

import paramiko
from paramiko.ssh_exception import SSHException

# todo: Move to config files
USERNAME = 'root'
PASSWORD = 'dcouser'
KEY_FILENAME = '/root/.ssh/authorized_keys'


class Node(object):
    # pylint: disable=too-few-public-methods
    """
    Contains all the attributes of the nodes.
    """

    # pylint: disable=too-many-arguments
    def __init__(
            self,
            ip_address,
            username=USERNAME,
            password=PASSWORD,
            key_file_path=KEY_FILENAME,
            port=22
    ):
        self.host = ip_address
        self.user = username
        self.password = password
        self.port = port
        self.key_path = key_file_path


class NodeCommunicationHandler(object):
    """
    All the communication to remote node will be taken care by this class.
    All the communication will be handled by Paramiko.
    """
    def __init__(self, node):
        self.node = node
        self.ssh = None
        self.sftp = None
        self.host = self.node.host

    def establish_connection(self):
        """
        Initiate a connection with the node.
        """
        self.ssh = paramiko.SSHClient()
        self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            self.ssh.connect(
                self.node.host,
                username=self.node.user,
                password=self.node.password,
                # key_filename=self.node.key_path
            )
        except SSHException:
            # todo: DO the necessary logging. Log the error string as well
            pass

    def open_ftp_channel(self):
        """
        Open secure ftp connection with the node
        """
        try:
            self.sftp = self.ssh.open_sftp()
        except SSHException:
            # todo: DO the necessary logging. Log the error string as well
            pass

    def close_ftp_channel(self):
        """
        Close the ftp channel
        """
        self.sftp.close()

    def close_connection(self):
        """
        Gracefully close the communication channel.
        """
        try:
            if self.sftp:
                self.close_ftp_channel()
            self.ssh.close()
        except SSHException:
            # todo: DO the necessary logging.
            # Since we are closing, ignore it
            pass

    def execute_command(self, command):
        """
        Execute the command at node
        """
        try:
            return self.ssh.exec_command(command)
        except (SSHException, IOError):
            # todo: DO the necessary logging. Log the error string as well
            pass
        return None

    def get_file(self, remote_file, local_file):
        """
        Get a file from node
        """
        try:
            self.sftp.get(remote_file, local_file)
        except (SSHException, IOError):
            # todo: DO the necessary logging. Log the error string as well
            pass

    def put_file(self, local_file, remote_file):
        """
        Put a file in node
        """
        try:
            self.sftp.put(local_file, remote_file)
        except (SSHException, IOError):
            # todo: DO the necessary logging. Log the error string as well
            pass
