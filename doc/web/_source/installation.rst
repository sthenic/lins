.. _`lins_installation`:

************
Installation
************

Depending on your operating system you have different installation methods open
to you. Please refer to the relevant section below for further instructions.

.. important::

    This tool only supports 64-bit operating systems running on x86 platforms.

.. _`install_linux`:

Linux
=====

If your distribution supports installation from ``.deb`` files, please follow
:ref:`these <install_deb>` instructions. Otherwise, a slightly more manual
approach is required:

.. TODO: Proper links

1. Get the latest release archive `here <https://github.com/sthenic/lins/releases>`_.

2. Verify the MD5 checksum of the archive. (*OPTIONAL*)

3. Unpack the archive to a persistent location.

4. Add the resulting path to your ``PATH`` variable.

5. Open a terminal session and verify the installation by calling the tool with
   ``lins``.

To uninstall the package, perform the above steps in reverse: remove the
``PATH`` entry and delete the files.

.. _`install_deb`:

Debian-based Distributions
--------------------------

For Debian-based distributions: Debian, Ubuntu and the likes, there is a
``.deb`` package for each release to simplify the installation process.

1. Get the latest ``.deb`` package `here <https://github.com/sthenic/lins/releases>`_.

2. Verify the MD5 checksum of the package. (*OPTIONAL*)

3. Install the ``.deb`` package with e.g.

.. code-block:: bash

    $ sudo dpkg -i lins-0.1.0-x86_64.deb

4. Open a terminal session and verify the installation by calling the tool with
   ``lins``.

To remove the package call

.. code-block:: bash

    $ sudo dpkg -r lins

.. _`install_windows`:

Windows
=======

1. Get the latest release archive for 64-bit Windows `here <https://github.com/sthenic/lins/releases>`_.

2. Verify the MD5 checksum of the archive. (*OPTIONAL*)

3. Unpack the archive to a persistent location.

4. Add the resulting path to your ``PATH`` variable.

5. Open a Command Prompt or PowerShell session and verify the installation by
   calling the tool with ``lins``.

Uninstalling the tool involves performing the above steps in reverse, i.e.

* removing the entry from your ``PATH`` variable and
* removing the directory containing the unpacked release archive.
