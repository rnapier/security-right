#!/usr/bin/python
#
# Demonstrate how an attacker can modify an encrypted message without knowing
# the password
#
# Alice wants to send money to Bob. She creates a message to send to her bank
# and encrypts it with a shared secret known only to her and her bank.
#
# Eve only knows that the characters "Bob" will occur at index 12. She wants to
# change those characters to "Eve" when the message is decrypted. She has access
# to the ciphertext in transit and can modify the ciphertext before it arrives
# at the bank.
#
# The lesson here is: when using an unauthenticated mode with AES (such as CBC
# or CTR) you must use an HMAC to verify that your ciphertext has not been
# modified in transit. If you are not including an authentication mechanism
# (such as HMAC), then your use of AES is insecure, no matter how strong AES may
# be.
#
# If you want to understand this and many other cryptography issues much better,
# I highly recommend Dan Boneh's Cryptography I class through Coursera:
# https://www.coursera.org/course/crypto

import subprocess
import os

### The data

# The original message. (Eve knows a little bit about this string.)
msg = "Amt:$100.To:Bob.From:Alice.Seq:PQ123.Comment:Here's the money I owe you."

# The original key shared by Alice and bank
# Totally random and Eve doesn't know it. 256 random bits, so she's not going to
# guess it either.
KEY_SIZE = 32
key = os.urandom(KEY_SIZE)

# The original IV
# This is part of the message, so Eve knows it. If you're using a NULL (0) IV,
# then you've made Eve's job even easier, and you've introduced other security
# problems that can allow Eve to decrypt part of the message (that a story for
# another example). Your IV must be random and unique (sepecifically, you should
# never reuse the same IV and key).
BLOCK_SIZE = 16
iv = os.urandom(BLOCK_SIZE)

# The string Eve would like to inject and the location.
newMsg = "Eve"
newMsgLoc = 12

# A little helper function
def toHex(bytes):
	return ''.join('%02X' % ord(byte) for byte in bytes)

### The logic

# Alice creates an encrypted message (cipher)
sslout,sslerror = subprocess.Popen(
    ['openssl', 'enc', '-aes-256-cbc', '-K', toHex(key), '-iv', toHex(iv)],
    stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE
    ).communicate(msg)
cipher = sslout

# Eve has access to cipher and to iv. She calculates a new iv that will modify
# how the first block is decrypted. For each byte she wants to replace, she
# calculates (original_iv ^ original_msg ^ new_msg) where ^ is xor.
new_iv = list(iv)
for index in range(newMsgLoc, newMsgLoc + len(newMsg)):
	new_iv[index] = chr(ord(iv[index]) ^ ord(msg[index]) ^ ord(newMsg[index - newMsgLoc]))
new_iv = ''.join(new_iv)


# Eve now sends the new bundle to the bank. cipher is unchanged, but she sends
# a different IV. The bank already knows the shared "key"
newMsg,sslerror = subprocess.Popen(
    ['openssl', 'enc', '-d', '-aes-256-cbc', '-nosalt', '-K', toHex(key), '-iv', toHex((new_iv))],
    stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE
    ).communicate(cipher)

# The bank decrypts, and this is what they read:
print "original=" + msg
print "modified=" + newMsg

# Some debugging tools
# print "    IV=" + toHex(iv)
# print "   NIV=" + toHex(new_iv)
# print " cipher" + ''.join('%02X' % ord(byte) for byte in cipher[0:16])
# print "   msg=" + ''.join('%02X' % ord(byte) for byte in msg[0:16])
# print "newMsg=" + ''.join('%02X' % ord(byte) for byte in newMsg[0:16])
# print newMsg
# print sslerror