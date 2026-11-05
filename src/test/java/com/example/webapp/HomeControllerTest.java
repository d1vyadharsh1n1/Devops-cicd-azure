package com.example.webapp;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;


@WebMvcTest(HomeController.class)
@TestPropertySource(properties = {"app.message=Hello Test", "app.version=test-sha"})
class HomeControllerTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void homePageShowsMessageAndVersion() throws Exception {
        mvc.perform(get("/"))
           .andExpect(status().isOk())
           .andExpect(content().string(containsString("Hello Test")))
           .andExpect(content().string(containsString("test-sha")));
    }

    @Test
    void versionEndpointReturnsJson() throws Exception {
        mvc.perform(get("/api/version"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.version").value("test-sha"))
           .andExpect(jsonPath("$.message").value("Hello Test"));
    }
}
