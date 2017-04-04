These are notes for the contruction of VulkanMemoryManager (VkM).

1. Q: Is there any use for aliasing part of a resource?
   A: Probably not. In order to effectivly make use of a partial alias, the
      application would need to do the following:
      - Synchronize the use of the aliased portion, which would need to be done
        already with no or full aliasing.
      - Have multiple separate uses for different parts of the resource.
        (E.g. a single arrayed Image where each layer is for a different model.)
      - Ensurance from other parts of the system to not touch that portion.
        That said, some *Views would be able to be used, with synchronization.
      - The use of linear Images, to define the memory map for subresources.
        Otherwise, the entirety of the Images would alias.
      With this in mind, VkM does not support partial aliasing.
