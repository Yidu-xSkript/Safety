package com.safety.accountability

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PornListTest {
    @Test fun matchesKnownSitesAndSubdomains() {
        assertTrue(PornList.isPorn("pornhub.com"))
        assertTrue(PornList.isPorn("www.pornhub.com"))
        assertTrue(PornList.isPorn("m.xvideos.com"))
        assertTrue(PornList.isPorn("XHAMSTER.COM"))          // case-insensitive
    }

    @Test fun sparesLookalikesAndCleanHosts() {
        assertFalse(PornList.isPorn("notporn.com"))          // must not match porn.com
        assertFalse(PornList.isPorn("google.com"))
        assertFalse(PornList.isPorn("news.ycombinator.com"))
        assertFalse(PornList.isPorn(null))
        assertFalse(PornList.isPorn(""))
    }
}
