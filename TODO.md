## Roadmap Items

### Resources

- Add cookbook override property for logstash_pipeline.
- Add template variables property for logstash_pipeline.
  
### Testing

- Add Chefspec tests.
- Inspec tests for logstash_install upgrade action
    - How to detect upgrade was successful?
- Add port checks to Inspec tests (better way of checking that logstash is running correctly)

### Nice to Have

- Allow editing or overriding logstash service file
    - Will probably require significant refactoring