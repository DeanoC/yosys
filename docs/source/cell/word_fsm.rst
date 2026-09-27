Finite state machines
---------------------

The optional ``STATE_INIT`` parameter is an index into ``STATE_TABLE`` for the
power-up state. Its default, -1, leaves power-up unspecified. This is independent
of ``STATE_RST``, which identifies the reset state. Older cells without
``STATE_INIT`` retain their uninitialized behavior.

Inactive bits in one-hot state encodings use don't-care markers in the table;
initialization maps those bits to zero.

.. autocellgroup:: fsm
   :members:
   :source:
   :linenos:
